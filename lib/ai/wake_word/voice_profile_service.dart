import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:viernes/core/logging/app_logger.dart';

/// Qué tan exigente es el reconocimiento de la voz del dueño.
enum VoiceStrictness {
  /// Acepta aunque hables distinto (resfriado, lejos del teléfono); otra
  /// persona con voz parecida podría activarlo.
  relaxed,
  normal,

  /// Solo tu voz bien clara; a veces habrá que repetir «Viernes».
  strict,
}

/// Estado de la voz registrada en este teléfono.
@immutable
class VoiceProfileStatus {
  const VoiceProfileStatus({
    this.enrolled = false,
    this.samples = 0,
    this.strictness = VoiceStrictness.normal,
    this.accepted = 0,
    this.rejected = 0,
  });

  factory VoiceProfileStatus.fromMap(Map<Object?, Object?> map) =>
      VoiceProfileStatus(
        enrolled: map['enrolled'] == true,
        samples: (map['samples'] as num?)?.toInt() ?? 0,
        strictness: switch (map['strictness']) {
          'RELAXED' => VoiceStrictness.relaxed,
          'STRICT' => VoiceStrictness.strict,
          _ => VoiceStrictness.normal,
        },
        accepted: (map['accepted'] as num?)?.toInt() ?? 0,
        rejected: (map['rejected'] as num?)?.toInt() ?? 0,
      );

  static const none = VoiceProfileStatus();

  final bool enrolled;
  final int samples;
  final VoiceStrictness strictness;

  /// Veces que reconoció al dueño al decir «Viernes».
  final int accepted;

  /// Veces que no se abrió porque la voz no era la del dueño.
  final int rejected;
}

/// Por qué no sirvió una grabación.
enum SampleProblem { none, quiet, short, permission, error }

/// Resultado de grabar una muestra (registro o prueba).
@immutable
class VoiceSample {
  const VoiceSample({
    required this.ok,
    this.problem = SampleProblem.none,
    this.count = 0,
    this.accepted,
    this.similarity,
  });

  factory VoiceSample.fromMap(Map<Object?, Object?>? map) {
    if (map == null) {
      return const VoiceSample(ok: false, problem: SampleProblem.error);
    }
    return VoiceSample(
      ok: map['ok'] == true,
      problem: map['ok'] == true
          ? SampleProblem.none
          : switch (map['reason']) {
              'quiet' => SampleProblem.quiet,
              'short' => SampleProblem.short,
              'permission' => SampleProblem.permission,
              _ => SampleProblem.error,
            },
      count: (map['count'] as num?)?.toInt() ?? 0,
      accepted: map['accepted'] as bool?,
      similarity: (map['similarity'] as num?)?.toDouble(),
    );
  }

  final bool ok;
  final SampleProblem problem;

  /// Muestras válidas en el registro en curso.
  final int count;

  /// En una prueba: si reconoció la voz.
  final bool? accepted;

  /// En una prueba: parecido de 0 a 1.
  final double? similarity;
}

/// Registro de la voz del dueño. La activación por voz solo funciona con
/// una voz registrada, y solo se abre si reconoce esa voz.
abstract interface class VoiceProfileService {
  /// Grabaciones necesarias para registrar la voz.
  static const samplesNeeded = 5;

  Future<VoiceProfileStatus> status();

  /// Empieza un registro nuevo (descarta lo grabado antes sin guardar).
  Future<void> startEnrollment();

  /// Graba unos segundos mientras la persona dice «Viernes».
  Future<VoiceSample> recordSample();

  /// Guarda la voz con las muestras grabadas. `false` si faltan.
  Future<bool> finishEnrollment();

  /// Graba y dice si reconoce la voz registrada.
  Future<VoiceSample> testSample();

  Future<void> setStrictness(VoiceStrictness value);

  Future<void> delete();
}

class AndroidVoiceProfileService implements VoiceProfileService {
  static const _channel = MethodChannel('com.ramdsoft.viernes/voice_profile');
  static const _sampleMs = 2500;

  @override
  Future<VoiceProfileStatus> status() async {
    final map = await _call<Map<Object?, Object?>>('status');
    return map == null
        ? VoiceProfileStatus.none
        : VoiceProfileStatus.fromMap(map);
  }

  @override
  Future<void> startEnrollment() => _call<void>('startEnrollment');

  @override
  Future<VoiceSample> recordSample() async => VoiceSample.fromMap(
    await _call<Map<Object?, Object?>>('recordSample', {'ms': _sampleMs}),
  );

  @override
  Future<bool> finishEnrollment() async =>
      await _call<bool>('finishEnrollment') ?? false;

  @override
  Future<VoiceSample> testSample() async => VoiceSample.fromMap(
    await _call<Map<Object?, Object?>>('testSample', {'ms': _sampleMs}),
  );

  @override
  Future<void> setStrictness(VoiceStrictness value) =>
      _call<void>('setStrictness', {'value': value.name.toUpperCase()});

  @override
  Future<void> delete() => _call<void>('delete');

  Future<T?> _call<T>(String method, [Map<String, Object?>? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      AppLogger.error('Registro de voz: $method', error: error);
      return null;
    }
  }
}
