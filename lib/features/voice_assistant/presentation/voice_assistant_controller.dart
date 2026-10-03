import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viernes/ai/ai_providers.dart';
import 'package:viernes/ai/dataset/training_sample.dart';
import 'package:viernes/ai/nlu/es/category_classifier.dart';
import 'package:viernes/ai/nlu/es/spanish_cancel_detector.dart';
import 'package:viernes/ai/nlu/es/spanish_place_trigger.dart';
import 'package:viernes/ai/nlu/es/spanish_relative_event.dart';
import 'package:viernes/ai/nlu/es/spanish_reply_parser.dart';
import 'package:viernes/ai/nlu/es/spanish_rule_interpreter.dart';
import 'package:viernes/ai/nlu/es/spanish_share_parser.dart';
import 'package:viernes/ai/nlu/es/spanish_speech.dart';
import 'package:viernes/ai/nlu/es/spanish_task_splitter.dart';
import 'package:viernes/ai/nlu/es/spanish_text.dart';
import 'package:viernes/ai/nlu/interpretation.dart';
import 'package:viernes/ai/speech/speech_recognizer.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/core/error/result.dart';
import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/core/utils/date_x.dart';
import 'package:viernes/features/account/presentation/account_providers.dart';
import 'package:viernes/features/calendar/domain/calendar_occurrences.dart';
import 'package:viernes/features/device/device_providers.dart';
import 'package:viernes/features/places/domain/place.dart';
import 'package:viernes/features/places/presentation/places_providers.dart';
import 'package:viernes/features/reminders/domain/entities/reminder.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_draft.dart';
import 'package:viernes/features/reminders/domain/entities/reminder_enums.dart';
import 'package:viernes/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:viernes/features/settings/presentation/settings_controller.dart';
import 'package:viernes/features/sharing/data/contacts_repository.dart';
import 'package:viernes/features/sharing/domain/sharing_models.dart';
import 'package:viernes/features/sharing/presentation/sharing_providers.dart';
import 'package:viernes/features/summaries/domain/daily_briefing.dart';
import 'package:viernes/features/voice_assistant/domain/voice_draft_builder.dart';
import 'package:viernes/features/voice_assistant/domain/voice_state.dart';

final NotifierProvider<VoiceAssistantController, VoiceState>
voiceAssistantProvider =
    NotifierProvider.autoDispose<VoiceAssistantController, VoiceState>(
      VoiceAssistantController.new,
    );

/// Decisión del usuario mientras se confirma: por voz o con un botón.
sealed class _Decision {
  const _Decision();
}

final class _SaveTapped extends _Decision {
  const _SaveTapped();
}

final class _CancelTapped extends _Decision {
  const _CancelTapped();
}

final class _ListenTapped extends _Decision {
  const _ListenTapped();
}

final class _VoiceReply extends _Decision {
  const _VoiceReply(this.text);

  final String text;
}

final class _NoReply extends _Decision {
  const _NoReply();
}

/// Conversación con Viernes:
/// "Te escucho" → escucha → entiende → pregunta lo que falta → confirma →
/// guarda (o responde la consulta de agenda).
class VoiceAssistantController extends Notifier<VoiceState> {
  static const _maxListenAttempts = 3;
  static const _maxTurns = 4;

  /// Cambia al cancelar o descartar: las tareas en curso de una
  /// conversación anterior dejan de modificar el estado.
  int _session = 0;
  bool _running = false;
  Completer<_Decision>? _decision;
  _Decision? _queuedDecision;

  final List<String> _utterances = [];
  Interpretation? _initial;
  ParsedReminder _draft = ParsedReminder.empty;
  bool _corrected = false;
  bool _firstWasCancel = false;

  /// «Recuérdale a Sofi…»: se envía a este contacto en vez de guardarse.
  Contact? _shareTo;

  /// Modo conducción: respuestas cortas.
  bool _driving = false;
  Future<bool>? _drivingCheck;

  /// Si la conversación confirma que de verdad dijeron «Viernes»: hubo una
  /// frase y no fue «me equivoqué» / «nada». Sirve para etiquetar la
  /// grabación de la activación.
  bool get wakeWasReal => _utterances.isNotEmpty && !_firstWasCancel;

  late SpeechRecognizer _recognizer;
  late Speaker _speaker;
  DateTime get _now => ref.read(clockProvider).now();
  Duration get _defaultLead =>
      ref.read(settingsControllerProvider).defaultLeadTime;

  @override
  VoiceState build() {
    // Se guardan aquí porque `ref` no se puede usar dentro de onDispose.
    final recognizer = _recognizer = ref.read(speechRecognizerProvider);
    final speaker = _speaker = ref.read(speakerProvider);
    ref.onDispose(() {
      _session++;
      _decision = null;
      unawaited(recognizer.cancel());
      unawaited(speaker.stop());
    });
    return const VoiceState();
  }

  // --- Acciones de la UI ---------------------------------------------------

  /// Inicia (o reinicia) la conversación.
  Future<void> start() async {
    if (_running) return;
    _running = true;
    final session = ++_session;
    _utterances.clear();
    _initial = null;
    _draft = ParsedReminder.empty;
    _corrected = false;
    _firstWasCancel = false;
    _shareTo = null;
    _queuedDecision = null;
    _driving = false;
    _drivingCheck = _detectDriving();
    state = const VoiceState(stage: VoiceStage.listening);
    try {
      await _run(session);
    } on Object catch (error, stack) {
      AppLogger.error(
        'Error en la conversación',
        error: error,
        stackTrace: stack,
      );
      if (_alive(session)) {
        _set(
          state.copyWith(
            stage: VoiceStage.failed,
            message: SpanishSpeech.didNotUnderstand,
            isListening: false,
          ),
        );
      }
    } finally {
      if (session == _session) _running = false;
    }
  }

  /// Lee el resumen del día en voz alta (al tocar el resumen de la mañana,
  /// desde el acceso directo o al pedirlo por voz).
  Future<void> briefing() async {
    if (_running) return;
    _running = true;
    final session = ++_session;
    _utterances.clear();
    _initial = null;
    _firstWasCancel = false;
    state = const VoiceState(stage: VoiceStage.thinking);
    try {
      _driving = await _detectDriving();
      _set(state.copyWith(driving: _driving));
      await _answerBriefing(session);
    } on Object catch (error, stack) {
      AppLogger.error('Error en el resumen', error: error, stackTrace: stack);
      if (_alive(session)) {
        _set(
          state.copyWith(
            stage: VoiceStage.failed,
            message: SpanishSpeech.didNotUnderstand,
          ),
        );
      }
    } finally {
      if (session == _session) _running = false;
    }
  }

  Future<bool> _detectDriving() async {
    try {
      return await ref.read(drivingDetectorProvider).isActive();
    } on Object {
      return false;
    }
  }

  void confirmSave() => _decide(const _SaveTapped());

  void listenAgain() => _decide(const _ListenTapped());

  /// Cancela la conversación sin guardar.
  Future<void> cancel() async {
    _decide(const _CancelTapped());
    _session++;
    _running = false;
    await _recognizer.cancel();
    await _speaker.stop();
    if (ref.mounted) state = const VoiceState();
  }

  /// Borrador con lo entendido hasta ahora, para terminar en el editor.
  /// Detiene la conversación.
  Future<ReminderDraft?> takeDraftForEditor() async {
    final draft = _draft;
    final confidence = _initial?.confidence;
    await cancel();
    if (draft.title.isEmpty && !draft.hasWhen) return null;
    return VoiceDraftBuilder.draft(
      draft,
      now: _now,
      defaultLead: _defaultLead,
      utterances: List.of(_utterances),
      confidence: confidence,
    );
  }

  void _decide(_Decision decision) {
    final pending = _decision;
    if (pending != null && !pending.isCompleted) {
      pending.complete(decision);
    } else {
      // Botón tocado mientras Viernes aún hablaba.
      _queuedDecision = decision;
      unawaited(_speaker.stop());
    }
  }

  // --- Flujo ---------------------------------------------------------------

  bool _alive(int session) => session == _session && ref.mounted;

  /// La conversación ya terminó (guardó, canceló o falló).
  bool get _ended =>
      state.stage == VoiceStage.done || state.stage == VoiceStage.failed;

  void _set(VoiceState value) {
    if (ref.mounted) state = value;
  }

  Future<void> _run(int session) async {
    final availability = await _recognizer.initialize();
    if (!_alive(session)) return;
    if (availability != SpeechAvailability.available) {
      await _finish(
        session,
        availability == SpeechAvailability.permissionDenied
            ? SpanishSpeech.permissionDenied
            : SpanishSpeech.unavailable,
        failed: true,
      );
      return;
    }

    _driving = await (_drivingCheck ?? Future.value(false));
    if (!_alive(session)) return;
    if (_driving) _set(state.copyWith(driving: true));

    final first = await _ask(
      session,
      SpanishSpeech.listening,
      retryPrompt: SpanishSpeech.noSpeech,
    );
    if (first == null) {
      if (_alive(session)) {
        await _finish(session, SpanishSpeech.gaveUp, failed: true);
      }
      return;
    }
    _utterances.add(first);
    // "Nada", "me equivoqué", "ya no lo necesito": se activó por error o
    // cambió de idea.
    if (SpanishCancelDetector.isCancel(first)) {
      _firstWasCancel = true;
      await _finish(session, SpanishSpeech.dismissed);
      return;
    }

    _set(state.copyWith(stage: VoiceStage.thinking, isListening: false));

    // «Buenos días», «¿cómo está mi día?»: el resumen del día.
    if (SpanishBriefingRequest.matches(first)) {
      await _answerBriefing(session);
      return;
    }

    // «¿Qué me toca en la lista de la casa?»
    final mine = SpanishShareParser.parseListMine(first);
    if (mine != null) {
      await _readList(session, mine, onlyMine: true);
      return;
    }

    // Listas compartidas: «agrega leche a la lista del mercado».
    final listAdd = SpanishShareParser.parseListAdd(first);
    if (listAdd != null) {
      await _addToList(session, listAdd);
      return;
    }
    final listToRead = SpanishShareParser.parseListRead(first);
    if (listToRead != null) {
      await _readList(session, listToRead);
      return;
    }

    // «Recuérdale a Sofi…»: se le envía a su Viernes.
    final share = SpanishShareParser.parseShare(first);
    if (share != null) {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) {
        await _finish(session, SpanishSpeech.shareNeedsAccount, failed: true);
        return;
      }
      final match = matchContactPrefix(
        share.afterTo,
        ref.read(contactsProvider),
      );
      if (match == null) {
        await _finish(
          session,
          SpanishSpeech.unknownContact(share.afterTo.split(' ').first),
          failed: true,
        );
        return;
      }
      _shareTo = match.contact;
      final rest = match.rest.replaceFirst(
        RegExp(r'^que\s+', caseSensitive: false),
        '',
      );
      _draft =
          (await ref.read(reminderInterpreterProvider).interpret(rest, _now))
              .reminder;
      if (!_alive(session)) return;
      if (!await _fillMissing(session)) return;
      if (ref.read(settingsControllerProvider).voiceConfirmation &&
          !await _confirm(session)) {
        return;
      }
      await _save(session);
      return;
    }

    // «Cuando llegue a casa»: recordatorio por ubicación, no por hora.
    final placeRequest = SpanishPlaceTrigger.parse(first);
    if (placeRequest != null) {
      await _saveByPlace(session, placeRequest);
      return;
    }

    final interpretation = await ref
        .read(reminderInterpreterProvider)
        .interpret(first, _now);
    if (!_alive(session)) return;
    _initial = interpretation;

    // «Dos días antes del cumpleaños de Sofi»: la fecha sale de otro
    // recordatorio de la agenda.
    final relative = await _relativeToEvent(first);
    if (!_alive(session)) return;
    if (relative != null) {
      _draft = relative;
      if (!await _fillMissing(session)) return;
      if (ref.read(settingsControllerProvider).voiceConfirmation &&
          !await _confirm(session)) {
        return;
      }
      await _save(session);
      return;
    }

    switch (interpretation.intent) {
      case VoiceIntent.queryAgenda:
        await _answerAgenda(session, interpretation.agenda!);
        return;
      case VoiceIntent.unknown:
        await _finish(session, SpanishSpeech.didNotUnderstand, failed: true);
        return;
      case VoiceIntent.createReminder:
        _draft = interpretation.reminder;
    }

    if (!await _fillMissing(session)) return;
    if (ref.read(settingsControllerProvider).voiceConfirmation &&
        !await _confirm(session)) {
      return;
    }
    await _save(session);
  }

  Future<void> _addToList(int session, ListAddRequest request) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      await _finish(session, SpanishSpeech.shareNeedsAccount, failed: true);
      return;
    }
    try {
      final list = await _findList(email, request.listName);
      if (!_alive(session)) return;
      if (list == null) {
        await _finish(
          session,
          SpanishSpeech.listNotFound(request.listName),
          failed: true,
        );
        return;
      }
      // «… para Sofi»: a quién le toca.
      String? assignedTo;
      String? assignedName;
      final spoken = request.assignee;
      if (spoken != null) {
        final who = _resolveAssignee(spoken, email, user.firstName, list);
        if (who == null) {
          await _finish(
            session,
            SpanishSpeech.unknownContact(spoken.split(' ').first),
            failed: true,
          );
          return;
        }
        (assignedTo, assignedName) = who;
      }
      final ids = ref.read(idGeneratorProvider);
      await ref
          .read(sharingRepositoryProvider)
          .addItems(list.id, [
            for (final item in request.items)
              SharedListItem(
                id: ids.next(),
                text: item,
                addedBy: user.firstName ?? email,
                addedAt: _now,
                assignedTo: assignedTo,
                assignedName: assignedName,
              ),
          ])
          .timeout(const Duration(seconds: 10));
      if (!_alive(session)) return;
      await _finish(
        session,
        assignedName == null
            ? SpanishSpeech.addedToList(request.items, list.name)
            : SpanishSpeech.addedToListFor(
                request.items,
                list.name,
                assignedName,
              ),
      );
    } on Object catch (error) {
      AppLogger.info('Lista compartida: $error');
      if (_alive(session)) {
        await _finish(session, SpanishSpeech.shareFailed, failed: true);
      }
    }
  }

  /// Correo y nombre de la persona a la que se asigna («para Sofi», «para
  /// mí»). Nulo si no es un contacto ni el propio usuario.
  (String, String)? _resolveAssignee(
    String spoken,
    String myEmail,
    String? myName,
    SharedList list,
  ) {
    final folded = SpanishText.fold(spoken).trim();
    if (folded == 'mi' || folded == 'mí' || folded == 'mi mismo') {
      return (myEmail.toLowerCase(), myName ?? myEmail);
    }
    final match = matchContactPrefix(spoken, ref.read(contactsProvider));
    if (match != null) return (match.contact.email, match.contact.name);
    return null;
  }

  Future<void> _readList(
    int session,
    String listName, {
    bool onlyMine = false,
  }) async {
    final email = ref.read(authRepositoryProvider).currentUser?.email;
    if (email == null) {
      await _finish(session, SpanishSpeech.shareNeedsAccount, failed: true);
      return;
    }
    try {
      final list = await _findList(email, listName);
      if (!_alive(session)) return;
      if (list == null) {
        await _finish(
          session,
          SpanishSpeech.listNotFound(listName),
          failed: true,
        );
        return;
      }
      final items = await ref
          .read(sharingRepositoryProvider)
          .watchItems(list.id)
          .first
          .timeout(const Duration(seconds: 10));
      if (!_alive(session)) return;
      final pending = [
        for (final i in items)
          if (!i.done) i,
      ];
      final me = email.toLowerCase();
      await _finish(
        session,
        onlyMine
            ? SpanishSpeech.listMine(list.name, [
                for (final i in pending)
                  if (i.assignedTo == me) i.text,
              ])
            : SpanishSpeech.listContentsWithOwners(list.name, [
                for (final i in pending)
                  (i.text, i.assignedTo == me ? 'tú' : i.assignedName),
              ]),
      );
    } on Object catch (error) {
      AppLogger.info('Lista compartida: $error');
      if (_alive(session)) {
        await _finish(session, SpanishSpeech.shareFailed, failed: true);
      }
    }
  }

  Future<SharedList?> _findList(String email, String spoken) async {
    final lists = await ref
        .read(sharingRepositoryProvider)
        .watchLists(email)
        .first
        .timeout(const Duration(seconds: 10));
    final wanted = SpanishText.fold(spoken).trim();
    for (final list in lists) {
      if (list.key == wanted) return list;
    }
    for (final list in lists) {
      if (list.key.contains(wanted) || wanted.contains(list.key)) return list;
    }
    return null;
  }

  /// Envía el recordatorio a [_shareTo] en vez de guardarlo aquí.
  Future<void> _sendShared(int session, ReminderDraft draft) async {
    final contact = _shareTo!;
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null || user.email == null) {
      await _finish(session, SpanishSpeech.shareNeedsAccount, failed: true);
      return;
    }
    try {
      await ref
          .read(sharingRepositoryProvider)
          .send(
            SharedReminder(
              id: ref.read(idGeneratorProvider).next(),
              fromUid: user.uid,
              fromName: user.firstName ?? user.email!,
              fromEmail: user.email!,
              toEmail: contact.email,
              title: draft.title,
              dueAt: draft.dueAt,
              leadTime: draft.leadTime,
              createdAt: _now,
            ),
          )
          .timeout(const Duration(seconds: 15));
      if (!_alive(session)) return;
      await _finish(session, SpanishSpeech.sentTo(contact.name));
    } on Object catch (error) {
      AppLogger.info('No se pudo enviar el recordatorio: $error');
      if (_alive(session)) {
        await _finish(session, SpanishSpeech.shareFailed, failed: true);
      }
    }
  }

  /// Guarda un recordatorio por ubicación tras confirmar (si está activada
  /// la confirmación por voz).
  Future<void> _saveByPlace(int session, PlaceTriggerRequest request) async {
    final repository = ref.read(placesRepositoryProvider);
    final place = SpanishPlaceTrigger.findPlace(
      request.placeText,
      await repository.places(),
    );
    if (!_alive(session)) return;
    if (place == null) {
      await _finish(
        session,
        SpanishSpeech.unknownPlace(request.placeText),
        failed: true,
      );
      return;
    }
    var title = request.task;
    if (title.isEmpty) {
      final answer = await _ask(session, SpanishSpeech.askTitle);
      if (answer == null || !_alive(session)) return;
      _utterances.add(answer);
      if (SpanishCancelDetector.isCancel(answer)) {
        await _finish(session, SpanishSpeech.cancelled);
        return;
      }
      title = SpanishRuleInterpreter.cleanTitle(answer);
    }
    final where = SpanishSpeech.atPlace(place.name, onArrive: request.onArrive);
    if (ref.read(settingsControllerProvider).voiceConfirmation) {
      final reply = await _ask(session, '$title, $where. ¿Lo guardo?');
      if (reply == null || !_alive(session)) return;
      _utterances.add(reply);
      final kind = ref.read(replyParserProvider).parse(reply, _now).kind;
      if (kind != ReplyKind.affirm) {
        await _finish(session, SpanishSpeech.cancelled);
        return;
      }
    }
    await repository.saveReminder(
      LocationReminder(
        id: ref.read(idGeneratorProvider).next(),
        title: title,
        placeId: place.id,
        onArrive: request.onArrive,
        createdAt: _now,
      ),
    );
    final permission = await ref.read(locationBridgeProvider).status();
    if (!_alive(session)) return;
    _set(
      state.copyWith(
        stage: VoiceStage.done,
        message: SpanishSpeech.savedAtPlace(
          where,
          needsPermission: !permission.ready,
        ),
        isListening: false,
      ),
    );
    await _speaker.speak(state.message);
  }

  /// Si la frase pide un aviso relativo a otro recordatorio y ese
  /// recordatorio existe, el borrador con la fecha ya calculada.
  Future<ParsedReminder?> _relativeToEvent(String text) async {
    final request = SpanishRelativeEvent.parse(text);
    if (request == null) return null;
    final active = await ref.read(reminderRepositoryProvider).watchByStatus({
      ReminderStatus.pending,
      ReminderStatus.snoozed,
    }).first;
    final now = _now;
    final event = SpanishRelativeEvent.findEvent(
      request.eventText,
      active,
      now,
    );
    if (event == null) return null;
    final due = event.dueAt.subtract(request.offset);
    if (!due.isAfter(now)) return null;
    return ParsedReminder(
      title: request.task.isNotEmpty
          ? request.task
          : SpanishSpeech.upcoming(event.title),
      exactDue: due,
      leadTime: Duration.zero,
      category: event.category,
    );
  }

  /// Dice [prompt] y escucha. Si no oye nada, repite con [retryPrompt].
  /// Devuelve `null` si no hubo respuesta o se canceló.
  Future<String?> _ask(
    int session,
    String prompt, {
    String? retryPrompt,
  }) async {
    for (var attempt = 0; attempt < _maxListenAttempts; attempt++) {
      final text = attempt == 0 ? prompt : retryPrompt ?? prompt;
      _set(
        state.copyWith(
          stage: VoiceStage.listening,
          message: text,
          transcript: '',
          isListening: false,
        ),
      );
      await _speaker.speak(text);
      if (!_alive(session)) return null;

      _set(state.copyWith(isListening: true));
      final result = await _recognizer.listen(
        onPartial: (partial) {
          if (_alive(session)) _set(state.copyWith(transcript: partial));
        },
      );
      if (!_alive(session)) return null;
      _set(state.copyWith(isListening: false));

      switch (result) {
        case SpeechHeard(:final text):
          _set(state.copyWith(transcript: text));
          return text;
        case SpeechSilence():
          continue;
        case SpeechCancelled():
          return null;
        case SpeechFailure(:final message):
          if (message == 'permission') {
            await _finish(
              session,
              SpanishSpeech.permissionDenied,
              failed: true,
            );
            return null;
          }
          continue;
      }
    }
    return null;
  }

  /// Pregunta lo que falte (qué, cuándo, a qué hora).
  Future<bool> _fillMissing(int session) async {
    for (var turn = 0; turn < _maxTurns; turn++) {
      final now = _now;
      final missing = _draft.missing(now);
      final due = _draft.resolveDue(now);
      final isPast =
          due != null && due.isBefore(now.subtract(const Duration(minutes: 1)));
      if (missing.isEmpty && !isPast) return true;
      final slot = missing.isEmpty ? MissingSlot.when : missing.first;
      final question = isPast && missing.isEmpty
          ? SpanishSpeech.pastTime
          : switch (slot) {
              MissingSlot.title => SpanishSpeech.askTitle,
              MissingSlot.when => SpanishSpeech.askWhen,
              MissingSlot.time => SpanishSpeech.askTime,
            };
      _set(state.copyWith(preview: _preview()));
      final answer = await _ask(session, question);
      if (answer == null) {
        if (_alive(session)) {
          await _finish(session, SpanishSpeech.gaveUp, failed: true);
        }
        return false;
      }
      _utterances.add(answer);
      if (SpanishCancelDetector.isCancel(answer)) {
        await _finish(session, SpanishSpeech.cancelled);
        return false;
      }
      _corrected = true;
      final parsed =
          (await ref
                  .read(reminderInterpreterProvider)
                  .interpret(answer, _now, expecting: slot))
              .reminder;
      if (!_alive(session)) return false;
      if (slot == MissingSlot.title) {
        final title = parsed.title.isNotEmpty
            ? parsed.title
            : SpanishRuleInterpreter.cleanTitle(answer);
        _draft = _withTitle(_draft.merge(parsed.copyWith(title: '')), title);
      } else {
        // La respuesta a "¿a qué hora?" no debe cambiar el título.
        _draft = _draft.merge(parsed.copyWith(title: ''));
      }
    }
    await _finish(session, SpanishSpeech.didNotUnderstand, failed: true);
    return false;
  }

  /// Lee lo entendido y espera "sí", una corrección o un botón.
  Future<bool> _confirm(int session) async {
    var speakQuestion = true;
    for (var turn = 0; turn < _maxTurns * 2; turn++) {
      final preview = _preview();
      final taskCount = SpanishTaskSplitter.split(preview.title).length;
      final question =
          (_shareTo == null ? '' : SpanishSpeech.sendTo(_shareTo!.name)) +
          (taskCount > 1 ? SpanishSpeech.severalTasks(taskCount) : '') +
          (_driving
              ? SpanishSpeech.confirmationShort(
                  title: preview.title,
                  due: preview.due!,
                  now: _now,
                )
              : SpanishSpeech.confirmation(
                  title: preview.title,
                  due: preview.due!,
                  leadTime: preview.leadTime,
                  recurrence: preview.recurrence,
                  now: _now,
                ));
      _set(
        state.copyWith(
          stage: VoiceStage.confirming,
          // Tras un silencio se muestra la ayuda en vez de repetir la pregunta.
          message: speakQuestion ? question : SpanishSpeech.tapToConfirm,
          preview: preview,
          transcript: '',
          isListening: false,
        ),
      );
      if (speakQuestion) await _speaker.speak(question);
      if (!_alive(session)) return false;

      final decision = await _awaitDecision(session, listen: speakQuestion);
      if (!_alive(session)) return false;
      speakQuestion = true;

      switch (decision) {
        case _SaveTapped():
          return true;
        case _CancelTapped():
          await _finish(session, SpanishSpeech.cancelled);
          return false;
        case _ListenTapped():
          final text = await _listenOnce(session);
          if (text == null) {
            speakQuestion = false;
            continue;
          }
          if (await _applyReply(session, text)) return true;
          if (!_alive(session) || _ended) {
            return false;
          }
        case _NoReply():
          _set(state.copyWith(message: SpanishSpeech.tapToConfirm));
          speakQuestion = false;
        case _VoiceReply(:final text):
          if (await _applyReply(session, text)) return true;
          if (!_alive(session) || _ended) {
            return false;
          }
      }
    }
    return false;
  }

  /// Aplica la respuesta. Devuelve `true` si hay que guardar.
  Future<bool> _applyReply(int session, String text) async {
    _utterances.add(text);
    final reply = ref.read(replyParserProvider).parse(text, _now);
    switch (reply.kind) {
      case ReplyKind.affirm:
        return true;
      case ReplyKind.cancel:
        await _finish(session, SpanishSpeech.cancelled);
        return false;
      case ReplyKind.correction:
        _corrected = true;
        _draft = _draft.merge(reply.correction!);
        return false;
      case ReplyKind.deny:
        final change = await _ask(session, SpanishSpeech.askWhatToChange);
        if (change == null) return false;
        _utterances.add(change);
        if (SpanishCancelDetector.isCancel(change)) {
          await _finish(session, SpanishSpeech.cancelled);
          return false;
        }
        _corrected = true;
        final second = ref.read(replyParserProvider).parse(change, _now);
        if (second.kind == ReplyKind.correction) {
          _draft = _draft.merge(second.correction!);
        } else {
          // Sin fecha ni hora: es el texto nuevo de la tarea.
          _draft = _withTitle(
            _draft,
            SpanishRuleInterpreter.cleanTitle(change),
          );
        }
        return false;
      case ReplyKind.unknown:
        _set(state.copyWith(message: SpanishSpeech.tapToConfirm));
        return false;
    }
  }

  Future<_Decision> _awaitDecision(int session, {required bool listen}) async {
    final queued = _queuedDecision;
    if (queued != null) {
      _queuedDecision = null;
      return queued;
    }
    final completer = _decision = Completer<_Decision>();
    if (listen) {
      _set(state.copyWith(isListening: true));
      unawaited(
        _recognizer
            .listen(
              onPartial: (partial) {
                if (_alive(session) && !completer.isCompleted) {
                  _set(state.copyWith(transcript: partial));
                }
              },
            )
            .then((result) {
              if (completer.isCompleted) return;
              switch (result) {
                case SpeechHeard(:final text):
                  completer.complete(_VoiceReply(text));
                case SpeechSilence() || SpeechFailure():
                  completer.complete(const _NoReply());
                case SpeechCancelled():
                  break;
              }
            }),
      );
    }
    final decision = await completer.future;
    _decision = null;
    if (listen && decision is! _VoiceReply && decision is! _NoReply) {
      await _recognizer.cancel();
    }
    _set(state.copyWith(isListening: false));
    return decision;
  }

  Future<String?> _listenOnce(int session) async {
    _set(state.copyWith(isListening: true, transcript: ''));
    final result = await _recognizer.listen(
      onPartial: (partial) {
        if (_alive(session)) _set(state.copyWith(transcript: partial));
      },
    );
    _set(state.copyWith(isListening: false));
    return result is SpeechHeard ? result.text : null;
  }

  Future<void> _save(int session) async {
    final now = _now;
    final draft = VoiceDraftBuilder.draft(
      _draft,
      now: now,
      defaultLead: _defaultLead,
      utterances: _utterances,
      confidence: _initial?.confidence,
    );
    if (_shareTo != null) {
      await _sendShared(session, draft);
      return;
    }
    // «Pagar la luz y llamar a mi mamá»: un recordatorio por tarea, con la
    // misma fecha y hora.
    final tasks = SpanishTaskSplitter.split(draft.title);
    if (tasks.length > 1) {
      await _saveMany(session, draft, tasks, now);
      return;
    }
    final result = await ref.read(createReminderProvider)(draft);
    if (!_alive(session)) return;
    switch (result) {
      case Ok(:final value):
        await _recordSample(value);
        _set(
          state.copyWith(
            stage: VoiceStage.done,
            message: _driving
                ? SpanishSpeech.savedShort(value.remindAt, now)
                : SpanishSpeech.saved(value.remindAt, now),
            saved: value,
            isListening: false,
          ),
        );
        await _speaker.speak(state.message);
      case Err(:final failure):
        await _finish(session, failure.message, failed: true);
    }
  }

  Future<void> _saveMany(
    int session,
    ReminderDraft draft,
    List<String> tasks,
    DateTime now,
  ) async {
    final predict = ref.read(categoryPredictorProvider);
    Reminder? first;
    for (final task in tasks) {
      final result = await ref.read(createReminderProvider)(
        draft.copyWith(title: task, category: predict(task)),
      );
      if (!_alive(session)) return;
      if (result case Err(:final failure)) {
        await _finish(session, failure.message, failed: true);
        return;
      }
      if (result case Ok(:final value)) first ??= value;
    }
    if (first == null) return;
    await _recordSample(first);
    _set(
      state.copyWith(
        stage: VoiceStage.done,
        message: SpanishSpeech.savedMany(tasks.length, first.remindAt, now),
        saved: first,
        isListening: false,
      ),
    );
    await _speaker.speak(state.message);
  }

  Future<void> _answerAgenda(int session, AgendaQuery query) async {
    final active = await ref.read(reminderRepositoryProvider).watchByStatus({
      ReminderStatus.pending,
      ReminderStatus.snoozed,
    }).first;
    if (!_alive(session)) return;
    final items =
        active
            .where(
              (r) =>
                  !r.dueAt.isBefore(query.from) && r.dueAt.isBefore(query.to),
            )
            .toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final events = await ref
        .read(calendarReaderProvider)
        .events(query.from, query.to);
    if (!_alive(session)) return;
    final answer = SpanishSpeech.agenda(
      reminders: items,
      from: query.from,
      isWeek: query.isWeek,
      now: _now,
      events: events,
      short: _driving,
    );
    _set(
      state.copyWith(
        stage: VoiceStage.done,
        message: answer,
        agenda: items,
        events: events,
        isListening: false,
      ),
    );
    await _speaker.speak(answer);
  }

  /// «Buenos días. Hoy tienes…»: lo de hoy, lo vencido, el calendario y lo
  /// que se acerca.
  Future<void> _answerBriefing(int session) async {
    final active = await ref.read(reminderRepositoryProvider).watchByStatus({
      ReminderStatus.pending,
      ReminderStatus.snoozed,
    }).first;
    final now = _now;
    final today = now.startOfDay;
    final events = await ref
        .read(calendarReaderProvider)
        .events(today, today.addDays(1));
    if (!_alive(session)) return;
    final message = DailyBriefing.compose(
      active: active,
      now: now,
      events: events,
      short: _driving,
    );
    final todayItems =
        CalendarOccurrences.expand(active, today, today.addDays(1))[today] ??
        const <Occurrence>[];
    _set(
      state.copyWith(
        stage: VoiceStage.done,
        message: message,
        agenda: [for (final o in todayItems) o.reminder],
        events: events,
        isListening: false,
      ),
    );
    await _speaker.speak(message);
  }

  Future<void> _finish(
    int session,
    String message, {
    bool failed = false,
  }) async {
    if (!_alive(session)) return;
    _set(
      state.copyWith(
        stage: failed ? VoiceStage.failed : VoiceStage.done,
        message: message,
        isListening: false,
      ),
    );
    await _speaker.speak(message);
  }

  /// Guarda el ejemplo para entrenar la IA, solo con consentimiento.
  Future<void> _recordSample(Reminder saved) async {
    final initial = _initial;
    if (initial == null ||
        !ref.read(settingsControllerProvider).dataCollectionConsent) {
      return;
    }
    try {
      await ref
          .read(trainingDataRepositoryProvider)
          .add(
            TrainingSample(
              utterances: List.of(_utterances),
              initialParse: initial.reminder.toJson(),
              finalResult: {
                'title': saved.title,
                'dueAt': saved.dueAt.toIso8601String(),
                'leadTimeMinutes': saved.leadTime.inMinutes,
                'recurrence': saved.recurrence.repeats
                    ? saved.recurrence.encode()
                    : null,
                'priority': saved.priority.name,
                'category': saved.category.name,
              },
              corrected: _corrected,
              confidence: initial.confidence,
              interpreterVersion: initial.interpreterVersion,
              createdAt: saved.createdAt,
            ),
          );
    } on Object catch (error) {
      // El dataset es secundario: nunca debe impedir guardar.
      AppLogger.error('No se pudo guardar el ejemplo', error: error);
    }
  }

  VoicePreview _preview() => VoiceDraftBuilder.preview(
    _draft,
    now: _now,
    defaultLead: _defaultLead,
  );

  ParsedReminder _withTitle(ParsedReminder parsed, String title) =>
      parsed.copyWith(
        title: title,
        category: parsed.category == ReminderCategory.other
            ? CategoryClassifier.classify(title)
            : parsed.category,
      );
}
