/// Falla de dominio: un error esperado que la UI sabe explicar al usuario.
///
/// Las excepciones inesperadas se registran y se convierten en
/// [UnexpectedFailure] en el borde de la capa de datos.
sealed class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => 'Failure: $message';
}

/// Los datos de entrada no cumplen una regla de negocio.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {this.field});

  /// Campo del formulario al que se refiere la falla, si aplica.
  final String? field;
}

/// El elemento solicitado no existe (p. ej. fue eliminado).
final class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

/// Error de almacenamiento local.
final class StorageFailure extends Failure {
  const StorageFailure(super.message, [this.cause]);

  final Object? cause;
}

/// Cualquier error no previsto.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, [this.cause]);

  final Object? cause;
}
