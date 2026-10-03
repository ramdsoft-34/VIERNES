import 'package:viernes/core/error/failure.dart';

/// Resultado de una operación que puede fallar de forma esperada.
///
/// Evita excepciones sueltas entre capas: quien llama está obligado a
/// manejar ambos casos con `switch`.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;

  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  Failure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final failure) => onErr(failure),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;
}

/// Ejecuta [action] y convierte cualquier excepción en [StorageFailure].
Future<Result<T>> guardStorage<T>(Future<T> Function() action) async {
  try {
    return Result.ok(await action());
  } on Object catch (error) {
    return Result.err(StorageFailure('No se pudo acceder a los datos', error));
  }
}
