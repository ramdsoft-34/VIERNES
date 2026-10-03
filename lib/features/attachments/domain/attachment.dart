import 'package:flutter/foundation.dart';

enum AttachmentKind { photo, audio }

/// Foto o nota de voz de un recordatorio («la foto del recibo», «lo que hay
/// que comprar, dicho con mi voz»).
@immutable
class Attachment {
  const Attachment({
    required this.id,
    required this.reminderId,
    required this.kind,
    required this.createdAt,
    this.localPath,
    this.remotePath,
    this.duration,
  });

  final String id;
  final String reminderId;
  final AttachmentKind kind;

  /// Archivo en el teléfono (nulo si aún no se descarga de la cuenta).
  final String? localPath;

  /// Ruta en la nube (nula si aún no se sube).
  final String? remotePath;

  /// Duración de la nota de voz.
  final Duration? duration;
  final DateTime createdAt;

  /// Extensión del archivo según el tipo.
  String get extension => kind == AttachmentKind.photo ? 'jpg' : 'm4a';

  Attachment copyWith({
    String? reminderId,
    String? localPath,
    String? remotePath,
  }) => Attachment(
    id: id,
    reminderId: reminderId ?? this.reminderId,
    kind: kind,
    createdAt: createdAt,
    localPath: localPath ?? this.localPath,
    remotePath: remotePath ?? this.remotePath,
    duration: duration,
  );

  @override
  bool operator ==(Object other) =>
      other is Attachment &&
      other.id == id &&
      other.reminderId == reminderId &&
      other.kind == kind &&
      other.localPath == localPath &&
      other.remotePath == remotePath &&
      other.duration == duration;

  @override
  int get hashCode =>
      Object.hash(id, reminderId, kind, localPath, remotePath, duration);
}
