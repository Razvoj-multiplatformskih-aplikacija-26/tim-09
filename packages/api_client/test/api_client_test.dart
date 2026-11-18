import 'dart:async';
import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:domain/domain.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:use_cases/testing.dart';
import 'package:use_cases/use_cases.dart';

Map<String, Object?> requestJson(String id, {int priceRsd = 1550, Map<String, Object?>? status}) => {
  'id': id,
  'clientId': 'u-client',
  'vehicle': {'type': 'sedan', 'plate': 'BG 123-AB'},
  'tier': 'economy',
  'address': {'text': 'Knez Mihailova 6'},
  'slot': {'start': '2026-11-19T09:00:00Z', 'durationMinutes': 45},
  'note': null,
  'createdAt': '2026-11-18T09:00:00Z',
  'priceRsd': priceRsd,
  'currency': 'RSD',
  'status': status ?? {'type': 'submitted'},
};

const sessionJson = {
  'user': {'id': 'u-client', 'username': 'marko', 'role': 'client'},
  'expiresAt': '2026-11-18T10:00:00Z',
  'token': 'secret-token',
};

http.Response json(int status, Object? body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

final class Harness {
  Harness(this.handler, {SessionTransport transport = SessionTransport.bearer, String? token = 'secret-token'})
    : session = SessionController(transport: transport) {
    if (token != null && transport == SessionTransport.bearer) session.start(token);
    if (transport == SessionTransport.cookie) session.start();
    api = CarWashApi(
      baseUrl: Uri.parse('http://localhost:8080'),
      client: MockClient((request) async {
        calls.add(request);
        return handler(request);
      }),
      session: session,
      timeout: const Duration(milliseconds: 200),
    );
  }

  final Future<http.Response> Function(http.Request request) handler;
  final SessionController session;
  final List<http.Request> calls = [];
  late final CarWashApi api;

  HttpWashRequestRepository get requests => HttpWashRequestRepository(api);
}

WashRequestDraft draft() => WashRequestDraft(
  vehicle: Vehicle(type: VehicleType.sedan, plate: LicensePlate.parse('BG 123-AB').valueOrNull!),
  tier: ServiceTier.economy,
  address: Address.parse('Knez Mihailova 6').valueOrNull!,
  slot: WashSlot.existing(DateTime.utc(2026, 11, 19, 9), const Duration(minutes: 45)),
  note: WashNote.parse('a' * 250).valueOrNull,
);

void main() {
  group('zahtevi', () {
    test('lista šalje opseg, stranicu, filter i Bearer token; vraća stranicu sa serverskom cenom', () async {
      final harness = Harness(
        (request) async => json(200, {
          'items': [requestJson('wr-21')],
          'total': 41,
          'limit': 20,
          'offset': 20,
        }),
      );
      final page = await harness.requests.list(
        const RequestQuery(scope: RequestScope.mine, offset: 20, status: RequestStatusFilter.submitted),
      );
      final call = harness.calls.single;
      expect(call.method, 'GET');
      expect(call.url.path, '/requests');
      expect(call.url.queryParameters, {'scope': 'mine', 'limit': '20', 'offset': '20', 'status': 'submitted'});
      expect(call.headers['Authorization'], 'Bearer secret-token');
      expect((page.total, page.offset, page.items.single.price.priceRsd), (41, 20, 1550));
    });

    test('detail van prve stranice, a 404 i 403 su nedostupan zapis', () async {
      final harness = Harness(
        (request) async => switch (request.url.path) {
          '/requests/wr-99' => json(200, {'request': requestJson('wr-99')}),
          '/requests/missing' => json(404, {'code': 'not_found', 'details': <String, Object?>{}}),
          _ => json(403, {'code': 'not_allowed', 'details': <String, Object?>{}}),
        },
      );
      expect((await harness.requests.find(const WashRequestId('wr-99')))?.id.value, 'wr-99');
      expect(await harness.requests.find(const WashRequestId('missing')), isNull);
      expect(await harness.requests.find(const WashRequestId('foreign')), isNull);
    });

    test('kreiranje: 201 je uspeh, telo nema vlasnika ni cenu', () async {
      final harness = Harness((request) async => json(201, {'request': requestJson('wr-new')}));
      final result = await harness.requests.create(draft());
      expect(result.valueOrNull?.id.value, 'wr-new');
      final body = jsonDecode(harness.calls.single.body) as Map<String, Object?>;
      expect(body.keys, unorderedEquals(['vehicle', 'tier', 'address', 'start', 'note']));
      expect(harness.calls.single.headers['Content-Type'], startsWith('application/json'));
    });

    test('422 nosi novu serversku granicu, a 409 nepoznat kod daje rezervnu grešku', () async {
      var status = 422;
      final harness = Harness(
        (request) async => status == 422
            ? json(422, {
                'code': 'note_too_long',
                'details': {'actualLength': 250, 'maxLength': 200},
              })
            : json(409, {'code': 'new_rule', 'details': <String, Object?>{}}),
      );
      expect((await harness.requests.create(draft())).errorOrNull, const NoteTooLong(250, maxLength: 200));
      status = 409;
      expect((await harness.requests.create(draft())).errorOrNull, isA<RemoteRuleViolation>());
    });

    test('komande idu na eksplicitne rute sa ugovornim telom', () async {
      final harness = Harness(
        (request) async => json(200, {
          'request': requestJson(
            'wr-1',
            status: {'type': 'accepted', 'washerId': 'w-1', 'acceptedBy': 'u-dispatcher', 'at': '2026-11-18T09:00:00Z'},
          ),
        }),
      );
      await harness.requests.assign(id: const WashRequestId('wr-1'), washerId: const WasherId('w-1'));
      await harness.requests.release(id: const WashRequestId('wr-1'));
      await harness.requests.cancel(id: const WashRequestId('wr-1'), reason: 'Otkazao dispečer.');
      expect(harness.calls.map((c) => (c.url.path, c.body)), [
        ('/requests/wr-1/assign', '{"washerId":"w-1"}'),
        ('/requests/wr-1/release', '{}'),
        ('/requests/wr-1/cancel', '{"reason":"Otkazao dispečer."}'),
      ]);
    });

    test('washer_busy je poslovni rezultat komande', () async {
      final harness = Harness(
        (request) async => json(409, {
          'code': 'washer_busy',
          'details': {'washerId': 'w-1'},
        }),
      );
      final result = await harness.requests.assign(id: const WashRequestId('wr-1'), washerId: const WasherId('w-1'));
      expect(result.errorOrNull, const WasherBusy(washerId: WasherId('w-1')));
    });

    test('perači dolaze sa servera zajedno sa dostupnošću', () async {
      final harness = Harness(
        (request) async => json(200, {
          'items': [
            {'id': 'w-1', 'name': 'Nikola Petrović', 'hasActiveJob': true},
          ],
        }),
      );
      final washers = await HttpWasherRepository(harness.api).washers();
      expect((washers.single.name, washers.single.hasActiveJob), ('Nikola Petrović', true));
    });
  });

  group('tehničke greške', () {
    test('500, 400, 405 i loš JSON su kontrolisana greška protokola', () async {
      for (final response in [
        json(500, {'code': 'server_error', 'details': <String, Object?>{}}),
        json(400, {'code': 'invalid_request', 'details': <String, Object?>{}}),
        json(405, {'code': 'method_not_allowed', 'details': <String, Object?>{}}),
        http.Response('<html>', 200),
        json(200, {'items': 'not a list'}),
      ]) {
        final harness = Harness((request) async => response);
        await expectLater(
          harness.requests.list(const RequestQuery(scope: RequestScope.mine)),
          throwsA(isA<ProtocolException>()),
        );
      }
    });

    test('timeout završava poziv, POST je neizvestan ishod i ne ponavlja se', () async {
      final harness = Harness((request) => Completer<http.Response>().future);
      await expectLater(
        harness.requests.create(draft()),
        throwsA(
          isA<NetworkException>()
              .having((e) => e.timedOut, 'timedOut', isTrue)
              .having((e) => e.outcomeUnknown, 'unknown', isTrue),
        ),
      );
      expect(harness.calls, hasLength(1));
    });

    test('nedostupan server je mrežna greška, čitanje nije neizvestan upis', () async {
      final harness = Harness((request) async => throw http.ClientException('Connection refused', request.url));
      await expectLater(
        harness.requests.list(const RequestQuery(scope: RequestScope.all)),
        throwsA(isA<NetworkException>().having((e) => e.outcomeUnknown, 'unknown', isFalse)),
      );
    });
  });

  group('sesija', () {
    test('401 na zaštićenom pozivu prekida sesiju jednom, i pri više paralelnih odgovora', () async {
      final harness = Harness(
        (request) async => json(401, {'code': 'session_expired', 'details': <String, Object?>{}}),
      );
      final events = <void>[];
      final subscription = harness.session.expired.listen(events.add);
      final calls = [
        for (var i = 0; i < 3; i++)
          harness.requests
              .list(const RequestQuery(scope: RequestScope.mine))
              .then<Object?>((_) => null, onError: (Object e) => e),
      ];
      final errors = await Future.wait(calls);
      await Future<void>.delayed(Duration.zero);
      expect(errors, everyElement(isA<SessionExpiredException>()));
      expect(events, hasLength(1));
      expect(harness.session.isActive, isFalse);
      await subscription.cancel();
    });

    test('zakasneli 401 stare sesije ne prekida novu prijavu', () async {
      final gate = Completer<void>();
      final harness = Harness((request) async {
        await gate.future;
        return json(401, {'code': 'session_revoked', 'details': <String, Object?>{}});
      });
      final events = <void>[];
      harness.session.expired.listen(events.add);
      final stale = harness.requests.list(const RequestQuery(scope: RequestScope.mine));
      harness.session.start('new-token');
      gate.complete();
      await expectLater(stale, throwsA(isA<SessionExpiredException>()));
      expect(events, isEmpty);
      expect(harness.session.authorization, 'Bearer new-token');
    });

    test('403 ne odjavljuje korisnika', () async {
      final harness = Harness((request) async => json(403, {'code': 'not_allowed', 'details': <String, Object?>{}}));
      final result = await harness.requests.release(id: const WashRequestId('wr-1'));
      expect(result.errorOrNull, isA<NotAllowed>());
      expect(harness.session.isActive, isTrue);
    });

    test('veb kolačić: bez Authorization zaglavlja', () async {
      final harness = Harness(
        (request) async => json(200, {'items': <Object?>[], 'total': 0, 'limit': 50, 'offset': 0}),
        transport: SessionTransport.cookie,
      );
      await harness.requests.list(const RequestQuery(scope: RequestScope.all, limit: 50));
      expect(harness.calls.single.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('prijava', () {
    HttpAuthRepository authOf(Harness harness, SessionStorage? storage, {ClientApplication? application}) =>
        HttpAuthRepository(api: harness.api, application: application ?? ClientApplication.mobile, storage: storage);

    test('native prijava šalje aplikaciju i transport, čuva token i koristi ga dalje', () async {
      final storage = InMemorySessionStorage();
      final harness = Harness((request) async => json(200, sessionJson), token: null);
      final session = await authOf(harness, storage).login(username: ' marko ', password: 'DemoPass123!');
      final body = jsonDecode(harness.calls.single.body) as Map<String, Object?>;
      expect(body, {
        'username': 'marko',
        'password': 'DemoPass123!',
        'application': 'mobile',
        'sessionTransport': 'bearer',
      });
      expect(harness.calls.single.headers.containsKey('Authorization'), isFalse);
      expect(session.user.username, 'marko');
      expect(session.toString(), isNot(contains('secret-token')));
      expect(storage.token, 'secret-token');
      expect(harness.session.authorization, 'Bearer secret-token');
    });

    test('pogrešna lozinka i pogrešna aplikacija su razlozi prijave, ne istek', () async {
      var code = 'invalid_credentials';
      final harness = Harness(
        (request) async =>
            json(code == 'invalid_credentials' ? 401 : 403, {'code': code, 'details': <String, Object?>{}}),
        token: null,
      );
      final events = <void>[];
      harness.session.expired.listen(events.add);
      final auth = authOf(harness, InMemorySessionStorage(), application: ClientApplication.backoffice);
      await expectLater(
        auth.login(username: 'marko', password: 'x'),
        throwsA(isA<LoginRejected>().having((e) => e.reason, 'reason', LoginFailure.invalidCredentials)),
      );
      code = 'wrong_application';
      await expectLater(
        auth.login(username: 'marko', password: 'DemoPass123!'),
        throwsA(isA<LoginRejected>().having((e) => e.reason, 'reason', LoginFailure.wrongApplication)),
      );
      expect(events, isEmpty);
    });

    test('obnova: sačuvan token → /auth/me', () async {
      final harness = Harness((request) async => json(200, {...sessionJson}..remove('token')), token: null);
      final session = await authOf(harness, InMemorySessionStorage('stored')).restore();
      expect(session?.user.role, Role.client);
      expect(harness.calls.single.url.path, '/auth/me');
      expect(harness.calls.single.headers['Authorization'], 'Bearer stored');
    });

    test('obnova: nevažeći token se briše, bez tokena nema poziva', () async {
      final storage = InMemorySessionStorage('stale');
      final harness = Harness(
        (request) async => json(401, {'code': 'session_expired', 'details': <String, Object?>{}}),
        token: null,
      );
      expect(await authOf(harness, storage).restore(), isNull);
      expect(storage.token, isNull);
      expect(await authOf(harness, storage).restore(), isNull);
      expect(harness.calls, hasLength(1));
    });

    test('obnova: prekid mreže ne briše prijavu', () async {
      final storage = InMemorySessionStorage('stored');
      final harness = Harness((request) async => throw http.ClientException('offline'), token: null);
      await expectLater(authOf(harness, storage).restore(), throwsA(isA<NetworkException>()));
      expect(storage.token, 'stored');
    });

    test('odjava: 204 se ne dekodira, token se briše tek posle servera', () async {
      final storage = InMemorySessionStorage('secret-token');
      var online = false;
      final harness = Harness((request) async {
        if (!online) throw http.ClientException('offline');
        return http.Response('', 204);
      });
      final auth = authOf(harness, storage);
      await expectLater(auth.logout(), throwsA(isA<NetworkException>()));
      expect(storage.token, 'secret-token');
      online = true;
      await auth.logout();
      expect(storage.token, isNull);
      expect(harness.session.isActive, isFalse);
    });

    test('istek sesije briše sačuvan native token', () async {
      final storage = InMemorySessionStorage('secret-token');
      final harness = Harness(
        (request) async => json(401, {'code': 'session_expired', 'details': <String, Object?>{}}),
      );
      authOf(harness, storage);
      await expectLater(
        harness.requests.list(const RequestQuery(scope: RequestScope.mine)),
        throwsA(isA<SessionExpiredException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(storage.token, isNull);
    });

    test('veb prijava traži kolačić i ne čuva token', () async {
      final harness = Harness(
        (request) async => json(200, {...sessionJson}..remove('token')),
        transport: SessionTransport.cookie,
      );
      harness.session.clear();
      final auth = authOf(harness, null, application: ClientApplication.backoffice);
      await auth.login(username: 'dispecer', password: 'DemoPass123!');
      final body = jsonDecode(harness.calls.single.body) as Map<String, Object?>;
      expect(body['sessionTransport'], 'cookie');
      expect(harness.session.isActive, isTrue);
      expect(harness.session.authorization, isNull);
    });
  });
}
