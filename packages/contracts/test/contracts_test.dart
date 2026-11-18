import 'dart:convert';

import 'package:contracts/contracts.dart';
import 'package:test/test.dart';

void main() {
  test('novi zahtev prolazi kroz JSON bez promene', () {
    final request = CreateRequest(
      vehicle: const VehicleDto(type: 'sedan', plate: 'BG 123-AB'),
      tier: 'economy',
      address: 'Knez Mihailova 6',
      start: DateTime.utc(2026, 11, 19, 9),
      note: 'Garaža',
    );
    final restored = CreateRequest.fromJson(jsonObject(jsonDecode(jsonEncode(request.toJson()))));
    expect(restored.toJson(), request.toJson());
  });

  test('klijent ne može da prosledi vlasnika ili gotovu cenu', () {
    final json = {
      'vehicle': {'type': 'sedan', 'plate': 'BG 123-AB'},
      'tier': 'economy',
      'address': {'text': 'Adresa'},
      'start': '2026-11-19T09:00:00Z',
      'clientId': 'someone-else',
    };
    expect(() => CreateRequest.fromJson(json), throwsFormatException);
  });

  test('vreme bez vremenske zone se odbija', () {
    expect(() => jsonInstant({'start': '2026-11-19T09:00:00'}, 'start'), throwsFormatException);
  });

  test('nepoznat kod i dodatna polja odgovora ne ruše dekodiranje', () {
    final error = ApiError.fromJson({
      'code': 'new_rule',
      'details': {'newLimit': 7},
      'serverVersion': 2,
    });
    expect(error.code, 'new_rule');
    expect(error.details['newLimit'], 7);
  });

  test('veb sesija se dekodira bez tokena', () {
    final session = SessionDto.fromJson({
      'user': {'id': 'u-client', 'username': 'marko', 'role': 'client'},
      'expiresAt': '2026-11-19T10:00:00Z',
    });
    expect(session.token, isNull);
    expect(session.toJson().containsKey('token'), isFalse);
  });
}
