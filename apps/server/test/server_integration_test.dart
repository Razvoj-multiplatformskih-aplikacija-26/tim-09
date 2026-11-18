import 'dart:convert';
import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:contracts/contracts.dart';
import 'package:domain/domain.dart';
import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart' show RelicServer;
import 'package:server/server.dart';
import 'package:server/src/ports/geocoding_gateway.dart';
import 'package:test/test.dart';
import 'package:use_cases/use_cases.dart';

final class MutableClock implements Clock {
  MutableClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

final class UnavailableGeocoding implements GeocodingGateway {
  @override
  Future<Coordinates?> locate(String address) async => throw const SocketException('Unavailable');
}

void main() {
  final testPort = Platform.environment['TEST_DATABASE_PORT'];
  group('Relic i PostgreSQL', () {
    final initialNow = DateTime.utc(2026, 11, 18, 9);
    final clock = MutableClock(initialNow);
    final client = http.Client();
    late Pool<void> database;
    late RelicServer server;
    late Uri base;
    late ServerConfig config;

    Map<String, Object?> decoded(http.Response response) => jsonObject(jsonDecode(response.body));

    Future<http.Response> post(String path, Map<String, Object?> body, {String? token, Map<String, String>? headers}) =>
        client.post(
          base.resolve(path),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
            ...?headers,
          },
          body: jsonEncode(body),
        );

    Future<String> login(String username, {String application = 'mobile'}) async {
      final response = await post(
        '/auth/login',
        LoginRequest(
          username: username,
          password: 'DemoPass123!',
          application: application,
          sessionTransport: 'bearer',
        ).toJson(),
      );
      expect(response.statusCode, 200, reason: response.body);
      return jsonString(decoded(response), 'token');
    }

    Map<String, Object?> newRequest({String plate = 'BG 123-AB', DateTime? start, String? note}) => CreateRequest(
      vehicle: VehicleDto(type: 'sedan', plate: plate),
      tier: 'economy',
      address: 'Knez Mihailova 6, Beograd',
      start: start ?? businessDate(2026, 11, 19, 10).toUtc(),
      note: note,
    ).toJson();

    Future<http.Response> get(String path, String token) =>
        client.get(base.resolve(path), headers: {'Authorization': 'Bearer $token'});

    setUpAll(() async {
      config = ServerConfig(databasePort: int.parse(testPort!), databaseName: 'carwash_test');
      database = openDatabase(config);
      await migrate(database, 'database/migrations');
      server = await ServerApp(
        auth: AuthService(database: database, config: config, clock: clock),
        requests: RequestService(store: PostgresRequestStore(database), clock: clock),
        config: config,
      ).build().serve(address: InternetAddress.loopbackIPv4, port: 0);
      base = Uri.parse('http://127.0.0.1:${server.port}');
    });

    setUp(() async {
      clock.value = initialNow;
      await database.execute('TRUNCATE sessions, wash_requests, washers, users');
      await seed(database, 'DemoPass123!', now: initialNow);
    });

    tearDownAll(() async {
      client.close();
      await server.close(force: true);
      await database.close();
    });

    test('seed ima dvanaest zapisa, sva stanja, uloge i heširane lozinke', () async {
      final count = await database.execute('SELECT COUNT(*) FROM wash_requests');
      expect(count.single.single, 12);
      final statuses = await database.execute('SELECT DISTINCT status FROM wash_requests');
      expect(statuses.length, 5);
      final users = await database.execute('SELECT password_hash FROM users');
      expect(users.length, 6);
      for (final row in users) {
        expect(row.single, isNot('DemoPass123!'));
        expect(BCrypt.checkpw('DemoPass123!', row.single as String), isTrue);
      }
      final duplicate = await database.execute("""
        SELECT washer_id FROM wash_requests WHERE status IN ('accepted', 'in_progress')
        GROUP BY washer_id HAVING COUNT(*) > 1
      """);
      expect(duplicate, isEmpty);
      final invalidTimes = await database.execute('''
        SELECT id FROM wash_requests WHERE finished_at < created_at OR cancelled_at < created_at
          OR arrived_at < created_at OR accepted_at < created_at
      ''');
      expect(invalidTimes, isEmpty);
    });

    test('ponovni bootstrap ne duplira podatke i čuva sesiju', () async {
      final token = await login('marko');
      await bootstrap(database, config, now: initialNow);
      expect((await database.execute('SELECT COUNT(*) FROM wash_requests')).single.single, 12);
      final restartedAuth = AuthService(database: database, config: config, clock: clock);
      expect((await restartedAuth.authenticate(token, 'bearer')).user.username, 'marko');
    });

    test('pogrešna lozinka i pogrešna aplikacija imaju različite korisničke kodove', () async {
      final wrong = await post('/auth/login', {
        'username': 'marko',
        'password': 'wrong',
        'application': 'mobile',
        'sessionTransport': 'bearer',
      });
      expect(wrong.statusCode, 401);
      expect(decoded(wrong)['code'], 'invalid_credentials');
      for (final username in ['marko', 'nikola']) {
        final response = await post('/auth/login', {
          'username': username,
          'password': 'DemoPass123!',
          'application': 'backoffice',
          'sessionTransport': 'bearer',
        });
        expect(response.statusCode, 403);
        expect(decoded(response)['code'], 'wrong_application');
      }
    });

    test('identitet, me, logout i istek proveravaju se na serveru', () async {
      expect((await client.get(base.resolve('/requests'))).statusCode, 401);
      final token = await login('marko');
      expect(jsonObject(decoded(await get('/auth/me', token))['user'])['username'], 'marko');
      expect((await post('/auth/logout', {}, token: token)).statusCode, 204);
      expect(decoded(await get('/auth/me', token))['code'], 'session_revoked');
      final nextToken = await login('marko');
      clock.value = initialNow.add(config.sessionTtl);
      expect(decoded(await get('/auth/me', nextToken))['code'], 'session_expired');
      expect((await get('/requests', 'forged-token')).statusCode, 401);
    });

    test('uloge vide samo dozvoljene zapise i server paginira filtriranu listu', () async {
      final marko = await login('marko');
      final mine = RequestPageDto.fromJson(decoded(await get('/requests?scope=mine&limit=2&offset=0', marko)));
      expect(mine.total, 6);
      expect(mine.items.length, 2);
      expect(mine.items.every((item) => item.clientId == 'u-client'), isTrue);
      final page2 = RequestPageDto.fromJson(decoded(await get('/requests?scope=mine&limit=2&offset=2', marko)));
      expect(
        page2.items.map((item) => item.id).toSet().intersection(mine.items.map((item) => item.id).toSet()),
        isEmpty,
      );
      expect((await get('/requests?scope=all', marko)).statusCode, 403);
      expect((await get('/requests/seed-2', marko)).statusCode, 403);
      final dispatcher = await login('dispecer', application: 'backoffice');
      expect(RequestPageDto.fromJson(decoded(await get('/requests?scope=all', dispatcher))).total, 12);
      final washer = await login('jovan');
      final jobs = RequestPageDto.fromJson(decoded(await get('/requests?scope=mine', washer)));
      expect(jobs.items.length, 1);
      expect(jobs.items.single.status.data['washerId'], 'w-2');
      expect((await get('/requests/seed-1', washer)).statusCode, 403);
    });

    test('novi zahtev dobija serverovog vlasnika, cenu, stanje i geokodiranje', () async {
      final token = await login('marko');
      final response = await post('/requests', newRequest(), token: token);
      expect(response.statusCode, 201, reason: response.body);
      final request = RequestResponse.fromJson(decoded(response)).request;
      expect(request.clientId, 'u-client');
      expect(request.priceRsd, 1400);
      expect(request.durationMinutes, 45);
      expect(request.status.type, 'submitted');
      expect(request.createdAt, initialNow);
      final coords = await database.execute(
        Sql.named('SELECT latitude, longitude FROM wash_requests WHERE id = @id'),
        parameters: {'id': request.id},
      );
      expect(coords.single[0], isNotNull);
      final dispatcher = await login('dispecer', application: 'backoffice');
      expect((await get('/requests/${request.id}', dispatcher)).statusCode, 200);
    });

    test('zaobilaženje forme i podmetanje identiteta ne prolaze', () async {
      final token = await login('marko');
      for (final extra in [
        {'clientId': 'u-other'},
        {'priceRsd': 1},
        {
          'status': {'type': 'completed'},
        },
        {'role': 'dispatcher'},
      ]) {
        expect((await post('/requests', {...newRequest(), ...extra}, token: token)).statusCode, 400);
      }
      final invalidPlate = await post('/requests', newRequest(plate: 'bad'), token: token);
      expect(invalidPlate.statusCode, 422);
      expect(decoded(invalidPlate)['code'], 'invalid_license_plate');
      final note = await post('/requests', newRequest(note: List.filled(301, 'a').join()), token: token);
      expect(decoded(note)['code'], 'note_too_long');
      expect(jsonObject(decoded(note)['details'])['maxLength'], 300);
      final soon = await post(
        '/requests',
        newRequest(start: initialNow.add(const Duration(minutes: 30))),
        token: token,
      );
      expect(decoded(soon)['code'], 'slot_too_soon');
    });

    test('sva polja novog zahteva proverava domen pre upisa', () async {
      final token = await login('marko');
      final cases = <(Map<String, Object?>, String)>[
        (
          {
            ...newRequest(),
            'address': {'text': '   '},
          },
          'address_missing',
        ),
        (newRequest(start: initialNow.add(const Duration(days: 8))), 'slot_too_far'),
        (newRequest(start: DateTime.utc(2026, 11, 19, 9, 15)), 'slot_not_on_half_hour'),
        (newRequest(start: DateTime.utc(2026, 11, 19, 5)), 'outside_working_hours'),
        (
          {...newRequest(start: businessDate(2026, 11, 19, 19).toUtc()), 'tier': 'professional'},
          'outside_working_hours',
        ),
      ];
      for (final (body, code) in cases) {
        final response = await post('/requests', body, token: token);
        expect(response.statusCode, 422, reason: response.body);
        expect(decoded(response)['code'], code);
      }
      final unknown = await post('/requests', {
        ...newRequest(),
        'vehicle': {'type': 'unknown', 'plate': 'BG 123-AB'},
      }, token: token);
      expect(unknown.statusCode, 400);
      final huge = await post('/requests', newRequest(note: List.filled(70000, 'a').join()), token: token);
      expect(huge.statusCode, 400);
      expect((await database.execute('SELECT COUNT(*) FROM wash_requests')).single.single, 12);
    });

    test('rok otkazivanja i izuzetak za kašnjenje koriste serversko vreme', () async {
      final request = (await PostgresRequestStore(database).find(const WashRequestId('seed-3')))!;
      clock.value = request.slot.start.subtract(const Duration(minutes: 30));
      var token = await login('marko');
      var response = await post('/requests/seed-3/cancel', {'reason': 'Kasno'}, token: token);
      expect(response.statusCode, 422);
      expect(decoded(response)['code'], 'cancellation_too_late');
      clock.value = request.slot.start.add(const Duration(minutes: 30));
      token = await login('marko');
      response = await post('/requests/seed-3/cancel', {'reason': 'Tačno 30 minuta'}, token: token);
      expect(response.statusCode, 422);
      clock.value = request.slot.start.add(const Duration(minutes: 31));
      response = await post('/requests/seed-3/cancel', {'reason': 'Perač kasni'}, token: token);
      expect(response.statusCode, 200);
    });

    test('nedostupan geocoder ne gubi zahtev sa tekstualnom adresom', () async {
      final service = RequestService(
        store: PostgresRequestStore(database),
        clock: clock,
        geocoding: UnavailableGeocoding(),
      );
      final result = await service.create(
        CreateRequest.fromJson(newRequest()),
        const User(id: UserId('u-client'), username: 'marko', role: Role.client),
      );
      expect(result.isSuccess, isTrue);
      final saved = await PostgresRequestStore(database).find(result.valueOrNull!.id);
      expect(saved!.address.text, 'Knez Mihailova 6, Beograd');
      final row = await database.execute(
        Sql.named('SELECT latitude FROM wash_requests WHERE id = @id'),
        parameters: {'id': saved.id.value},
      );
      expect(row.single.single, isNull);
    });

    test('dve staff akcije i otkazivanje tuđeg zapisa odbijaju se direktnim pozivom', () async {
      final token = await login('marko');
      expect((await post('/requests/seed-1/assign', {'washerId': 'w-1'}, token: token)).statusCode, 403);
      expect((await post('/requests/seed-3/release', {}, token: token)).statusCode, 403);
      expect((await post('/requests/seed-2/cancel', {'reason': 'Tuđi zahtev'}, token: token)).statusCode, 403);
      expect((await post('/requests/seed-1/cancel', {'reason': 'Moj zahtev'}, token: token)).statusCode, 200);
      final own = RequestResponse.fromJson(decoded(await get('/requests/seed-1', token))).request;
      expect(own.status.type, 'cancelled');
      expect(own.status.data['cancelledBy'], 'u-client');
    });

    test('istovremene dodele istog perača: tačno jedan uspeh', () async {
      final token = await login('dispecer', application: 'backoffice');
      final responses = await Future.wait([
        post('/requests/seed-1/assign', {'washerId': 'w-1'}, token: token),
        post('/requests/seed-2/assign', {'washerId': 'w-1'}, token: token),
      ]);
      expect(responses.map((response) => response.statusCode), unorderedEquals([200, 409]));
      expect(decoded(responses.firstWhere((response) => response.statusCode == 409))['code'], 'washer_busy');
      final active = await database.execute(
        "SELECT id FROM wash_requests WHERE washer_id = 'w-1' AND status IN ('accepted', 'in_progress')",
      );
      expect(active.length, 1);
    });

    test('isti zahtev ne može istovremeno da se dodeli različitim peračima', () async {
      await database.execute("""
        INSERT INTO users (id, username, password_hash, role)
        SELECT 'u-washer-4', 'luka', password_hash, 'washer' FROM users WHERE id = 'u-washer-1'
      """);
      await database.execute("INSERT INTO washers (id, user_id, name) VALUES ('w-4', 'u-washer-4', 'Luka')");
      final token = await login('dispecer', application: 'backoffice');
      final responses = await Future.wait([
        post('/requests/seed-1/assign', {'washerId': 'w-1'}, token: token),
        post('/requests/seed-1/assign', {'washerId': 'w-4'}, token: token),
      ]);
      expect(responses.map((response) => response.statusCode), unorderedEquals([200, 409]));
      expect(decoded(responses.firstWhere((response) => response.statusCode == 409))['code'], 'invalid_transition');
    });

    test('dva paralelna kreiranja poštuju najviše tri zahteva na čekanju', () async {
      final token = await login('marko');
      final responses = await Future.wait([
        post('/requests', newRequest(), token: token),
        post('/requests', newRequest(), token: token),
      ]);
      expect(responses.map((response) => response.statusCode), unorderedEquals([201, 409]));
      final rejected = decoded(responses.firstWhere((response) => response.statusCode == 409));
      expect(rejected['code'], 'too_many_pending_requests');
      expect(jsonObject(rejected['details'])['maxPending'], 3);
      final count = await database.execute(
        "SELECT COUNT(*) FROM wash_requests WHERE client_id = 'u-client' AND status IN ('submitted', 'accepted')",
      );
      expect(count.single.single, 3);
    });

    test('otkazivanje i vraćanje u red ne oživljavaju otkazan zahtev', () async {
      final owner = await login('marko');
      final staff = await login('dispecer', application: 'backoffice');
      final responses = await Future.wait([
        post('/requests/seed-3/cancel', {'reason': 'Promena plana'}, token: owner),
        post('/requests/seed-3/release', {}, token: staff),
      ]);
      expect(responses.first.statusCode, 200);
      expect([200, 409], contains(responses.last.statusCode));
      expect(RequestResponse.fromJson(decoded(await get('/requests/seed-3', owner))).request.status.type, 'cancelled');
    });

    test('zauzetost perača gleda sve poslove i posle vraćanja se osvežava', () async {
      final token = await login('dispecer', application: 'backoffice');
      final first = decoded(await get('/washers', token))['items'] as List<Object?>;
      expect(first.map(jsonObject).singleWhere((item) => item['id'] == 'w-2')['hasActiveJob'], isTrue);
      expect((await post('/requests/seed-3/release', {}, token: token)).statusCode, 200);
      final after = decoded(await get('/washers', token))['items'] as List<Object?>;
      expect(after.map(jsonObject).singleWhere((item) => item['id'] == 'w-2')['hasActiveJob'], isFalse);
    });

    test('veb cookie, CORS, obnova sesije i logout rade bez tokena u JSON-u', () async {
      const origin = 'http://localhost:3000';
      final preflight = await client.send(
        http.Request('OPTIONS', base.resolve('/requests'))
          ..headers.addAll({'Origin': origin, 'Access-Control-Request-Method': 'POST'}),
      );
      expect(preflight.statusCode, 204);
      expect(preflight.headers['access-control-allow-credentials'], 'true');
      await preflight.stream.drain<void>();
      final loggedIn = await post(
        '/auth/login',
        {'username': 'dispecer', 'password': 'DemoPass123!', 'application': 'backoffice', 'sessionTransport': 'cookie'},
        headers: {'Origin': origin},
      );
      expect(loggedIn.statusCode, 200, reason: loggedIn.body);
      expect(decoded(loggedIn).containsKey('token'), isFalse);
      final setCookie = loggedIn.headers['set-cookie']!;
      expect(setCookie.toLowerCase(), contains('httponly'));
      expect(setCookie.toLowerCase(), contains('max-age='));
      final cookie = setCookie.split(';').first;
      final me = await client.get(base.resolve('/auth/me'), headers: {'Cookie': cookie, 'Origin': origin});
      expect(me.statusCode, 200);
      expect(me.headers['access-control-allow-origin'], origin);
      expect((await post('/requests/seed-3/release', {}, headers: {'Cookie': cookie})).statusCode, 403);
      final logout = await post('/auth/logout', {}, headers: {'Cookie': cookie, 'Origin': origin});
      expect(logout.statusCode, 204);
      expect(logout.headers['set-cookie']!.toLowerCase(), contains('max-age=0'));
      expect(
        (await client.get(base.resolve('/auth/me'), headers: {'Cookie': cookie, 'Origin': origin})).statusCode,
        401,
      );
    });

    test('svaka zaštićena ruta proverava prijavu pre obrade podataka', () async {
      for (final path in ['/auth/me', '/requests', '/requests/seed-1', '/washers']) {
        expect((await client.get(base.resolve(path))).statusCode, 401, reason: path);
      }
      for (final path in [
        '/auth/logout',
        '/requests',
        '/requests/seed-1/cancel',
        '/requests/seed-1/assign',
        '/requests/seed-3/release',
      ]) {
        expect((await post(path, {})).statusCode, 401, reason: path);
      }
    });

    test('perač i dispečer nemaju klijentsku akciju kreiranja', () async {
      final washer = await login('nikola');
      final staff = await login('dispecer', application: 'backoffice');
      for (final token in [washer, staff]) {
        expect((await post('/requests', newRequest(), token: token)).statusCode, 403);
      }
      expect((await post('/requests/seed-1/assign', {'washerId': 'w-1'}, token: washer)).statusCode, 403);
      expect((await post('/requests/seed-3/release', {}, token: washer)).statusCode, 403);
      expect((await post('/requests/seed-3/cancel', {}, token: washer)).statusCode, 403);
      expect((await get('/washers', washer)).statusCode, 403);
    });

    test('nepostojeći zapisi i završna stanja ne menjaju bazu', () async {
      final token = await login('dispecer', application: 'backoffice');
      expect((await get('/requests/missing', token)).statusCode, 404);
      expect((await post('/requests/missing/assign', {'washerId': 'w-1'}, token: token)).statusCode, 404);
      expect((await post('/requests/seed-1/assign', {'washerId': 'missing'}, token: token)).statusCode, 404);
      expect((await post('/requests/seed-1/release', {}, token: token)).statusCode, 409);
      expect((await post('/requests/seed-3/assign', {'washerId': 'w-1'}, token: token)).statusCode, 409);
      for (final id in ['seed-5', 'seed-9']) {
        expect((await post('/requests/$id/cancel', {}, token: token)).statusCode, 409);
      }
      expect((await database.execute('SELECT COUNT(*) FROM wash_requests')).single.single, 12);
      expect((await PostgresRequestStore(database).find(const WashRequestId('seed-1')))!.status, isA<Submitted>());
    });

    test('dodela, vraćanje i ponovno dodeljivanje čuvaju stanje i autora', () async {
      final owner = await login('marko');
      final staff = await login('dispecer', application: 'backoffice');
      final first = await post('/requests/seed-1/assign', {'washerId': 'w-1'}, token: staff);
      expect(first.statusCode, 200);
      var dto = RequestResponse.fromJson(decoded(await get('/requests/seed-1', owner))).request;
      expect(dto.status.type, 'accepted');
      expect(dto.status.data['acceptedBy'], 'u-dispatcher');
      expect((await post('/requests/seed-1/release', {}, token: staff)).statusCode, 200);
      dto = RequestResponse.fromJson(decoded(await get('/requests/seed-1', owner))).request;
      expect(dto.status.toJson(), {'type': 'submitted'});
      expect((await post('/requests/seed-1/assign', {'washerId': 'w-1'}, token: staff)).statusCode, 200);
      final cancelled = await post('/requests/seed-4/cancel', {'reason': 'Otkazao dispečer'}, token: staff);
      expect(cancelled.statusCode, 200);
      expect(RequestResponse.fromJson(decoded(cancelled)).request.status.data['cancelledBy'], 'u-dispatcher');
      final washers = decoded(await get('/washers', staff))['items'] as List<Object?>;
      expect(washers.map(jsonObject).singleWhere((item) => item['id'] == 'w-3')['hasActiveJob'], isFalse);
    });

    test('granični dozvoljeni termini i cene proveravaju se preko HTTP-a', () async {
      final token = await login('marko');
      final bodies = [
        newRequest(start: initialNow.add(const Duration(hours: 1))),
        newRequest(start: initialNow.add(const Duration(days: 7))),
        {...newRequest(start: businessDate(2026, 11, 19, 18, 30).toUtc()), 'tier': 'professional'},
      ];
      for (final body in bodies) {
        final response = await post('/requests', body, token: token);
        expect(response.statusCode, 201, reason: response.body);
        final dto = RequestResponse.fromJson(decoded(response)).request;
        expect(dto.priceRsd, body['tier'] == 'professional' ? 2900 : 1400);
        expect(dto.durationMinutes, body['tier'] == 'professional' ? 90 : 45);
        expect((await post('/requests/${dto.id}/cancel', {}, token: token)).statusCode, 200);
      }
    });

    test('dužina napomene broji Unicode znakove i uklanja spoljne razmake', () async {
      final token = await login('marko');
      final emoji = List.filled(300, '👨‍👩‍👧‍👦').join();
      final response = await post('/requests', newRequest(note: '  $emoji  '), token: token);
      expect(response.statusCode, 201, reason: response.body);
      expect(RequestResponse.fromJson(decoded(response)).request.note, emoji);
      final rejected = await post('/requests', newRequest(note: '$emoji👨‍👩‍👧‍👦'), token: token);
      expect(rejected.statusCode, 422);
      expect(jsonObject(decoded(rejected)['details']), {'actualLength': 301, 'maxLength': 300});
    });

    test('neispravni tipovi, datumi, parametri i SQL tekst ostaju kontrolisane greške', () async {
      final token = await login('marko');
      for (final query in [
        'limit=0',
        'limit=-1',
        'limit=abc',
        'offset=-1',
        'offset=1.5',
        'scope=other',
        'status=unknown',
        'status=submitted%27%20OR%201%3D1',
      ]) {
        expect((await get('/requests?$query', token)).statusCode, 400, reason: query);
      }
      for (final body in <Map<String, Object?>>[
        {...newRequest(), 'start': '2026-11-31T09:00:00Z'},
        {...newRequest(), 'start': '2026-11-19T25:00:00Z'},
        {...newRequest(), 'start': '2026-11-19T09:00:00'},
        {...newRequest(), 'vehicle': null},
        {...newRequest(), 'note': 123},
        {
          ...newRequest(),
          'address': {'text': 'Adresa', 'clientId': 'u-other'},
        },
      ]) {
        final response = await post('/requests', body, token: token);
        expect(response.statusCode, 400, reason: '$body: ${response.body}');
      }
      expect((await get('/requests/%27%20OR%201%3D1--', token)).statusCode, 404);
      final injection = await post('/auth/login', {
        'username': "' OR 1=1 --",
        'password': 'anything',
        'application': 'mobile',
        'sessionTransport': 'bearer',
      });
      expect(injection.statusCode, 401);
      expect((await database.execute('SELECT COUNT(*) FROM wash_requests')).single.single, 12);
    });

    test('opoziv jedne sesije ne briše druge, a trenutna uloga se čita iz baze', () async {
      final first = await login('marko');
      final second = await login('marko');
      expect((await post('/auth/logout', {}, token: first)).statusCode, 204);
      expect((await get('/auth/me', first)).statusCode, 401);
      expect((await get('/auth/me', second)).statusCode, 200);
      final staff = await login('dispecer', application: 'backoffice');
      await database.execute("UPDATE users SET role = 'client' WHERE id = 'u-dispatcher'");
      expect((await post('/requests/seed-1/assign', {'washerId': 'w-1'}, token: staff)).statusCode, 403);
      expect(jsonObject(decoded(await get('/auth/me', staff))['user'])['role'], 'client');
    });

    test('Bearer i cookie se ne mešaju i ne mogu da zamene način izdavanja', () async {
      final token = await login('marko');
      final mixed = await client.get(
        base.resolve('/auth/me'),
        headers: {'Authorization': 'Bearer $token', 'Cookie': 'carwash_session=$token'},
      );
      expect(mixed.statusCode, 400);
      expect(
        (await client.get(base.resolve('/auth/me'), headers: {'Cookie': 'carwash_session=$token'})).statusCode,
        401,
      );
      expect(
        (await client.get(base.resolve('/auth/me'), headers: {'Authorization': 'Basic anything'})).statusCode,
        401,
      );
      expect(
        (await client.get(
          base.resolve('/auth/me'),
          headers: {'Cookie': 'carwash_session=a; carwash_session=b'},
        )).statusCode,
        400,
      );
    });

    test('32 istovremena kreiranja sa istim nalogom daju jedno preostalo mesto', () async {
      final token = await login('marko');
      final responses = await Future.wait(List.generate(32, (_) => post('/requests', newRequest(), token: token)));
      expect(responses.where((response) => response.statusCode == 201).length, 1);
      expect(
        responses
            .where((response) => response.statusCode == 409 && decoded(response)['code'] == 'too_many_pending_requests')
            .length,
        31,
      );
      final count = await database.execute(
        "SELECT COUNT(*) FROM wash_requests WHERE client_id = 'u-client' AND status IN ('submitted', 'accepted')",
      );
      expect(count.single.single, 3);
    });

    test('20 različitih klijenata konkuriše za jednog perača bez dvostruke dodele', () async {
      await database.execute("""
        INSERT INTO users (id, username, password_hash, role)
        SELECT 'stress-client-' || n, 'stress-user-' || n, u.password_hash, 'client'
        FROM generate_series(1, 20) AS n CROSS JOIN users u WHERE u.id = 'u-client'
      """);
      await database.execute("""
        INSERT INTO wash_requests (
          id, client_id, vehicle_type, plate, tier, address, start_at, duration_minutes, created_at, status
        )
        SELECT 'stress-request-' || n, 'stress-client-' || n, vehicle_type, plate, tier,
          address, start_at, duration_minutes, created_at, 'submitted'
        FROM generate_series(1, 20) AS n CROSS JOIN wash_requests WHERE id = 'seed-1'
      """);
      final token = await login('dispecer', application: 'backoffice');
      final responses = await Future.wait(
        List.generate(20, (i) => post('/requests/stress-request-${i + 1}/assign', {'washerId': 'w-1'}, token: token)),
      );
      expect(responses.where((response) => response.statusCode == 200).length, 1);
      expect(
        responses.where((response) => response.statusCode == 409 && decoded(response)['code'] == 'washer_busy').length,
        19,
      );
      expect(
        (await database.execute(
          "SELECT COUNT(*) FROM wash_requests WHERE washer_id = 'w-1' AND status IN ('accepted', 'in_progress')",
        )).single.single,
        1,
      );
    });

    test('CORS i JSON greške obuhvataju nepostojeću rutu i pogrešan HTTP metod', () async {
      const origin = 'http://localhost:3000';
      final missing = await client.get(base.resolve('/missing'), headers: {'Origin': origin});
      expect(missing.statusCode, 404);
      expect(missing.headers['access-control-allow-origin'], origin);
      expect(decoded(missing)['code'], 'not_found');
      final wrongMethod = await client.put(base.resolve('/requests'), headers: {'Origin': origin});
      expect(wrongMethod.statusCode, 405);
      expect(wrongMethod.headers['access-control-allow-origin'], origin);
      expect(decoded(wrongMethod)['code'], 'method_not_allowed');
      final preflight = await client.send(
        http.Request('OPTIONS', base.resolve('/missing'))
          ..headers.addAll({'Origin': origin, 'Access-Control-Request-Method': 'POST'}),
      );
      expect(preflight.statusCode, 204);
      expect(preflight.headers['access-control-allow-origin'], origin);
      await preflight.stream.drain<void>();
    });

    test('greške i neispravni zahtevi imaju JSON i CORS zaglavlja', () async {
      final token = await login('marko');
      final invalid = await get('/requests?limit=101', token);
      expect(invalid.statusCode, 400);
      expect(decoded(invalid)['code'], 'invalid_request');
      final denied = await client.get(base.resolve('/requests'), headers: {'Origin': 'http://localhost:3000'});
      expect(denied.statusCode, 401);
      expect(denied.headers['access-control-allow-origin'], 'http://localhost:3000');
      expect(
        (await client.get(base.resolve('/health'), headers: {'Origin': 'https://unknown.invalid'})).statusCode,
        403,
      );
      final malformed = await client.post(
        base.resolve('/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: '{',
      );
      expect(malformed.statusCode, 400);
      expect((await client.get(base.resolve('/missing'))).statusCode, 404);
    });
  }, skip: testPort == null ? 'Postaviti TEST_DATABASE_PORT za namensku carwash_test bazu.' : false);
}
