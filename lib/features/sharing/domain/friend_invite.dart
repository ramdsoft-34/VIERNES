import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Invitación para agregarse como contactos con un enlace.
///
/// El enlace lleva el nombre y el correo de quien invita (en base64, no
/// cifrado: solo se comparte con quien uno quiere). Quien lo abre agrega a
/// esa persona y, si hay internet, le deja una solicitud para que la otra
/// app lo agregue de vuelta sin hacer nada.
@immutable
class FriendInvite {
  const FriendInvite({required this.name, required this.email});

  /// Página que abre la app (o explica cómo instalarla).
  static const host = 'viernes-ramdsoft.web.app';

  final String name;

  /// En minúsculas.
  final String email;

  /// Código corto que viaja en el enlace.
  String get code => base64Url
      .encode(utf8.encode(jsonEncode({'n': name, 'e': email})))
      .replaceAll('=', '');

  /// `https://viernes-ramdsoft.web.app/amigo#<código>`: el código va en el
  /// fragmento, que el navegador nunca envía al servidor.
  String get link => 'https://$host/amigo#$code';

  /// Mensaje para WhatsApp, correo, etc.
  String message() =>
      '$name te invita a Viernes para compartir recordatorios y listas.\n'
      'Toca el enlace para agregarse: $link\n\n'
      'Si no se abre, copia este mensaje, abre Viernes y toca '
      '«Pegar invitación» en Compartir → Contactos.';

  static final _codeInText = RegExp(
    '(?:amigo[#/]|viernes://amigo/|^)([A-Za-z0-9_-]{12,})',
    multiLine: true,
  );

  /// Busca una invitación en un texto pegado o en el enlace que abrió la
  /// app. Nulo si no hay ninguna válida.
  static FriendInvite? tryParse(String? text) {
    if (text == null) return null;
    for (final match in _codeInText.allMatches(text.trim())) {
      final invite = fromCode(match.group(1)!);
      if (invite != null) return invite;
    }
    return null;
  }

  static FriendInvite? fromCode(String code) {
    try {
      final padded = code.padRight((code.length + 3) ~/ 4 * 4, '=');
      final data = jsonDecode(utf8.decode(base64Url.decode(padded)));
      if (data is! Map) return null;
      final name = (data['n'] as String? ?? '').trim();
      final email = (data['e'] as String? ?? '').trim().toLowerCase();
      if (name.isEmpty || !email.contains('@') || email.length > 200) {
        return null;
      }
      return FriendInvite(
        name: name.length > 60 ? name.substring(0, 60) : name,
        email: email,
      );
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is FriendInvite && other.name == name && other.email == email;

  @override
  int get hashCode => Object.hash(name, email);
}

/// Alguien abrió mi enlace y me agregó: la app me agrega a esa persona.
@immutable
class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.fromName,
    required this.fromEmail,
  });

  final String id;
  final String fromName;
  final String fromEmail;
}
