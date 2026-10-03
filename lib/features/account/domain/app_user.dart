import 'package:flutter/foundation.dart';

/// Usuario con sesión iniciada.
@immutable
class AppUser {
  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
  });

  /// Identificador estable de la cuenta; agrupa todos sus datos en la nube.
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  /// Primer nombre para saludar ("Hola, Ana").
  String? get firstName {
    final name = displayName?.trim();
    if (name == null || name.isEmpty) return null;
    return name.split(RegExp(r'\s+')).first;
  }

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.uid == uid &&
      other.email == email &&
      other.displayName == displayName &&
      other.photoUrl == photoUrl;

  @override
  int get hashCode => Object.hash(uid, email, displayName, photoUrl);
}
