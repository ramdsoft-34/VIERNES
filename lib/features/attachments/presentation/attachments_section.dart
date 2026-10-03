import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:viernes/app/providers.dart';
import 'package:viernes/core/extensions/context_x.dart';
import 'package:viernes/core/logging/app_logger.dart';
import 'package:viernes/features/attachments/data/attachments_repository.dart';
import 'package:viernes/features/attachments/domain/attachment.dart';
import 'package:viernes/features/attachments/presentation/attachment_providers.dart';
import 'package:viernes/features/voice_assistant/presentation/wake_word_controller.dart';

/// Fotos y notas de voz de un recordatorio.
///
/// Con [reminderId] trabaja directo sobre la base; sin él (recordatorio
/// nuevo) los guarda en [pending] hasta que se guarde el recordatorio.
/// Con [readOnly] solo se ven y se escuchan (pantalla de alerta).
class AttachmentsSection extends ConsumerWidget {
  const AttachmentsSection({
    this.reminderId,
    this.pending = const [],
    this.onPendingChanged,
    this.readOnly = false,
    this.dark = false,
    super.key,
  });

  final String? reminderId;
  final List<Attachment> pending;
  final ValueChanged<List<Attachment>>? onPendingChanged;
  final bool readOnly;

  /// Colores para fondo oscuro (alerta).
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final id = reminderId;
    final items = id == null
        ? pending
        : ref.watch(attachmentsProvider(id)).value ?? const <Attachment>[];
    if (readOnly && items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!readOnly)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.attachTitle,
              style: context.textTheme.labelLarge?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final a in items)
              a.kind == AttachmentKind.photo
                  ? _PhotoThumb(
                      attachment: a,
                      onDelete: readOnly
                          ? null
                          : () => _delete(context, ref, a),
                    )
                  : VoiceNoteChip(
                      attachment: a,
                      onDelete: readOnly
                          ? null
                          : () => _delete(context, ref, a),
                    ),
            if (!readOnly) ...[
              ActionChip(
                avatar: const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(l10n.attachPhoto),
                onPressed: () => unawaited(_addPhoto(context, ref)),
              ),
              ActionChip(
                avatar: const Icon(Icons.mic_none, size: 18),
                label: Text(l10n.attachVoiceNote),
                onPressed: () => unawaited(_addVoiceNote(context, ref)),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _store(WidgetRef ref, Attachment attachment) async {
    if (reminderId == null) {
      onPendingChanged?.call([...pending, attachment]);
    } else {
      await ref.read(attachmentsRepositoryProvider).add(attachment);
    }
  }

  Future<void> _addPhoto(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.attachCamera),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.attachGallery),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
      );
      if (picked == null) return;
      final id = ref.read(idGeneratorProvider).next();
      final path = await ref
          .read(attachmentFilesProvider)
          .importPhoto(picked.path, id);
      await _store(
        ref,
        Attachment(
          id: id,
          reminderId: reminderId ?? '',
          kind: AttachmentKind.photo,
          localPath: path,
          createdAt: ref.read(clockProvider).now(),
        ),
      );
    } on Object catch (error) {
      AppLogger.error('No se pudo agregar la foto', error: error);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.attachPhotoError)));
      }
    }
  }

  Future<void> _addVoiceNote(BuildContext context, WidgetRef ref) async {
    final id = ref.read(idGeneratorProvider).next();
    final file = await ref
        .read(attachmentFilesProvider)
        .fileFor(id, AttachmentKind.audio);
    if (!context.mounted) return;
    final duration = await showDialog<Duration>(
      context: context,
      barrierDismissible: false,
      builder: (_) => VoiceNoteRecorderDialog(path: file.path),
    );
    if (duration == null) return;
    await _store(
      ref,
      Attachment(
        id: id,
        reminderId: reminderId ?? '',
        kind: AttachmentKind.audio,
        localPath: file.path,
        duration: duration,
        createdAt: ref.read(clockProvider).now(),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Attachment attachment,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.attachDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (reminderId == null) {
      await AttachmentsRepository.deleteFile(attachment.localPath);
      onPendingChanged?.call([
        for (final a in pending)
          if (a.id != attachment.id) a,
      ]);
    } else {
      await ref.read(attachmentsRepositoryProvider).delete(attachment);
    }
  }
}

/// «1:05».
String _mmss(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// Ruta local del adjunto; si solo está en la nube, lo descarga.
final FutureProviderFamily<String?, Attachment> _localPathProvider =
    FutureProvider.autoDispose.family<String?, Attachment>(
      (ref, a) => ref.watch(attachmentSyncProvider).ensureLocal(a),
    );

class _PhotoThumb extends ConsumerWidget {
  const _PhotoThumb({required this.attachment, this.onDelete});

  final Attachment attachment;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(_localPathProvider(attachment)).value;
    final colors = context.colors;
    return GestureDetector(
      onTap: path == null
          ? null
          : () => unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (_) => _PhotoViewer(path: path),
                ),
              ),
            ),
      onLongPress: onDelete,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 72,
          height: 72,
          color: colors.surfaceContainerHighest,
          child: path == null
              ? Icon(Icons.cloud_download_outlined, color: colors.outline)
              : Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  cacheWidth: 216,
                  errorBuilder: (_, _, _) =>
                      Icon(Icons.broken_image_outlined, color: colors.outline),
                ),
        ),
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0B0D11),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0B0D11),
      foregroundColor: Colors.white,
    ),
    body: Center(
      child: InteractiveViewer(maxScale: 5, child: Image.file(File(path))),
    ),
  );
}

/// Nota de voz: toca para escuchar, mantén presionado para borrar.
class VoiceNoteChip extends ConsumerStatefulWidget {
  const VoiceNoteChip({required this.attachment, this.onDelete, super.key});

  final Attachment attachment;
  final VoidCallback? onDelete;

  @override
  ConsumerState<VoiceNoteChip> createState() => _VoiceNoteChipState();
}

class _VoiceNoteChipState extends ConsumerState<VoiceNoteChip> {
  AudioPlayer? _player;
  bool _playing = false;

  @override
  void dispose() {
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player?.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    final path = await ref
        .read(attachmentSyncProvider)
        .ensureLocal(widget.attachment);
    if (path == null || !mounted) return;
    try {
      final player = _player ??= AudioPlayer();
      await player.setFilePath(path);
      setState(() => _playing = true);
      await player.play();
      await player.stop();
    } on Object catch (error) {
      AppLogger.error('No se pudo reproducir la nota', error: error);
    }
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.attachment.duration;
    final label = duration == null
        ? context.l10n.attachVoiceNote
        : _mmss(duration);
    return GestureDetector(
      onLongPress: widget.onDelete,
      child: InputChip(
        avatar: Icon(_playing ? Icons.stop : Icons.play_arrow, size: 20),
        label: Text(label),
        onPressed: () => unawaited(_toggle()),
      ),
    );
  }
}

/// Graba una nota de voz (hasta 2 minutos). Devuelve la duración, o nulo si
/// se canceló.
class VoiceNoteRecorderDialog extends ConsumerStatefulWidget {
  const VoiceNoteRecorderDialog({required this.path, super.key});

  final String path;

  static const maxDuration = Duration(minutes: 2);

  @override
  ConsumerState<VoiceNoteRecorderDialog> createState() =>
      _VoiceNoteRecorderDialogState();
}

class _VoiceNoteRecorderDialogState
    extends ConsumerState<VoiceNoteRecorderDialog> {
  final _recorder = AudioRecorder();
  final _watch = Stopwatch();
  Timer? _ticker;
  bool _recording = false;
  String? _error;
  late final WakeWordController _wake;

  @override
  void initState() {
    super.initState();
    _wake = ref.read(wakeWordControllerProvider.notifier);
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      // La escucha de «Viernes» suelta el micrófono mientras se graba.
      await _wake.pause();
      if (!await _recorder.hasPermission()) {
        if (mounted) setState(() => _error = context.l10n.attachMicDenied);
        return;
      }
      await _recorder.start(
        const RecordConfig(
          sampleRate: 16000,
          bitRate: 32000,
          numChannels: 1,
        ),
        path: widget.path,
      );
      _watch.start();
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) return;
        if (_watch.elapsed >= VoiceNoteRecorderDialog.maxDuration) {
          unawaited(_finish(save: true));
        } else {
          setState(() {});
        }
      });
      if (mounted) setState(() => _recording = true);
    } on Object catch (error) {
      AppLogger.error('No se pudo grabar', error: error);
      if (mounted) setState(() => _error = context.l10n.attachRecordError);
    }
  }

  Future<void> _finish({required bool save}) async {
    _ticker?.cancel();
    _watch.stop();
    final navigator = Navigator.of(context);
    try {
      if (_recording) await _recorder.stop();
    } on Object catch (error) {
      AppLogger.error('No se pudo terminar la grabación', error: error);
    }
    _recording = false;
    final long = _watch.elapsed > const Duration(milliseconds: 600);
    if (!save || !long) {
      await AttachmentsRepository.deleteFile(widget.path);
    }
    navigator.pop(save && long ? _watch.elapsed : null);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_recorder.dispose());
    unawaited(_wake.resume());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final elapsed = _watch.elapsed;
    final time = _mmss(elapsed);
    return AlertDialog(
      title: Text(l10n.attachRecording),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _error == null ? Icons.mic : Icons.mic_off,
            size: 56,
            color: _error == null ? Colors.red : context.colors.error,
          ),
          const SizedBox(height: 12),
          Text(
            _error ?? time,
            textAlign: TextAlign.center,
            style: context.textTheme.headlineSmall,
          ),
          if (_error == null) ...[
            const SizedBox(height: 8),
            Text(
              l10n.attachRecordingHint,
              textAlign: TextAlign.center,
              style: context.textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => unawaited(_finish(save: false)),
          child: Text(l10n.actionCancel),
        ),
        if (_error == null)
          FilledButton(
            onPressed: _recording ? () => unawaited(_finish(save: true)) : null,
            child: Text(l10n.attachStop),
          ),
      ],
    );
  }
}
