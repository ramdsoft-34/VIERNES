import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:viernes/ai/nlu/es/spanish_text.dart';
import 'package:viernes/features/sharing/domain/sharing_models.dart';

/// Contactos para compartir. Se guardan junto a las preferencias, así viajan
/// con la cuenta y se recuperan en otro teléfono.
class ContactsRepository {
  ContactsRepository(this._prefs);

  final SharedPreferences _prefs;

  /// Con el prefijo de las preferencias para que se sincronice con la cuenta.
  static const _key = 'settings.contacts';

  List<Contact> all() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return [
        for (final item in jsonDecode(raw) as List)
          Contact.fromJson(Map<String, Object?>.from(item as Map)),
      ]..sort((a, b) => a.name.compareTo(b.name));
    } on FormatException {
      return const [];
    }
  }

  Future<void> save(Contact contact) async {
    final others = all().where((c) => c.key != contact.key);
    await _write([...others, contact]);
  }

  Future<void> remove(Contact contact) =>
      _write(all().where((c) => c != contact).toList());

  /// Por nombre dicho en voz alta («Sofi», «mi mamá»).
  Contact? find(String spoken) {
    final wanted = SpanishText.fold(
      spoken,
    ).replaceFirst(RegExp(r'^(?:a\s+)?(?:mi|la|el)\s+'), '').trim();
    if (wanted.isEmpty) return null;
    Contact? partial;
    for (final contact in all()) {
      final key = contact.key.replaceFirst(RegExp(r'^(?:mi|la|el)\s+'), '');
      if (key == wanted) return contact;
      if (key.startsWith(wanted) || wanted.startsWith(key)) partial ??= contact;
    }
    return partial;
  }

  Future<void> _write(List<Contact> contacts) => _prefs.setString(
    _key,
    jsonEncode([for (final c in contacts) c.toJson()]),
  );
}

/// Separa el contacto al inicio de la frase: «mi mamá que compre pan» →
/// (mamá, «que compre pan»). Elige el nombre más largo que coincida.
({Contact contact, String rest})? matchContactPrefix(
  String text,
  List<Contact> contacts,
) {
  final folded = SpanishText.fold(text).trim();
  final original = text.trim();
  ({Contact contact, String rest})? best;
  var bestLength = 0;
  for (final contact in contacts) {
    final name = contact.key.replaceFirst(RegExp(r'^(?:mi|la|el)\s+'), '');
    for (final prefix in ['', 'mi ', 'la ', 'el ']) {
      final candidate = '$prefix$name';
      if (folded == candidate || folded.startsWith('$candidate ')) {
        if (candidate.length > bestLength) {
          bestLength = candidate.length;
          best = (
            contact: contact,
            rest: original.substring(candidate.length).trim(),
          );
        }
      }
    }
  }
  return best;
}
