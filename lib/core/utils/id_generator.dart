import 'package:uuid/uuid.dart';

abstract interface class IdGenerator {
  String next();
}

class UuidIdGenerator implements IdGenerator {
  const UuidIdGenerator();

  static const _uuid = Uuid();

  @override
  String next() => _uuid.v7();
}
