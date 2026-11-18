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

  test('nemogući datumi, sati i pomeraji se odbijaju bez normalizacije', () {
    for (final value in [
      '2026-11-31T09:00:00Z',
      '2026-02-29T09:00:00Z',
      '2026-13-01T09:00:00Z',
      '2026-11-19T25:00:00Z',
      '2026-11-19T09:60:00Z',
      '2026-11-19T09:00:60Z',
      '2026-11-19T09:00:00+99:00',
      '2026-11-19T09:00:00+01:99',
    ]) {
      expect(() => jsonInstant({'start': value}, 'start'), throwsFormatException, reason: value);
    }
  });

  test('validan prestupni datum, UTC pomeraj i mikrosekunde čuvaju trenutak', () {
    expect(jsonInstant({'start': '2028-02-29T10:00:00+01:00'}, 'start'), DateTime.utc(2028, 2, 29, 9));
    expect(
      jsonInstant({'start': '2026-11-19T09:00:00.123456Z'}, 'start'),
      DateTime.utc(2026, 11, 19, 9, 0, 0, 123, 456),
    );
  });

  test('dodatni podaci odgovora ne lome prethodni DTO vozila', () {
    final vehicle = VehicleDto.fromJson({'type': 'sedan', 'plate': 'BG 123-AB', 'displayName': 'Limuzina'});
    expect(vehicle.plate, 'BG 123-AB');
    expect(
      () => CreateRequest.fromJson({
        'vehicle': {'type': 'sedan', 'plate': 'BG 123-AB', 'clientId': 'u-other'},
        'tier': 'economy',
        'address': {'text': 'Adresa'},
        'start': '2026-11-19T09:00:00Z',
      }),
      throwsFormatException,
    );
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
