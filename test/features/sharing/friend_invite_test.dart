import 'package:flutter_test/flutter_test.dart';
import 'package:viernes/features/sharing/domain/friend_invite.dart';

void main() {
  const invite = FriendInvite(name: 'Ricardo Peña', email: 'ricardo@gmail.com');

  test('el código va y vuelve con tildes y eñes', () {
    expect(FriendInvite.fromCode(invite.code), invite);
    expect(invite.code, isNot(contains('=')));
  });

  test('encuentra la invitación en el mensaje pegado de WhatsApp', () {
    expect(FriendInvite.tryParse(invite.message()), invite);
    expect(FriendInvite.tryParse('mira: ${invite.link} gracias'), invite);
    expect(FriendInvite.tryParse('viernes://amigo/${invite.code}'), invite);
  });

  test('ignora textos que no son invitaciones', () {
    expect(FriendInvite.tryParse('hola, ¿cómo vas?'), isNull);
    expect(FriendInvite.tryParse(null), isNull);
    expect(FriendInvite.fromCode('abcdefghijklmnop'), isNull);
  });

  test('el enlace lleva el código en el fragmento', () {
    expect(
      invite.link,
      startsWith('https://viernes-ramdsoft.web.app/amigo#'),
    );
  });
}
