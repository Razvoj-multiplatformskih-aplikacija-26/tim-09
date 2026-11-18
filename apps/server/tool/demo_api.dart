import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final base = Uri.parse(arguments.firstOrNull ?? 'http://localhost:8080');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);

  Future<({int status, Map<String, Object?> body})> call(
    String method,
    String path, {
    String? token,
    Map<String, Object?>? body,
  }) async {
    final request = await client.openUrl(method, base.resolve(path));
    if (token != null) request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close().timeout(const Duration(seconds: 10));
    final text = await utf8.decoder.bind(response).join();
    return (
      status: response.statusCode,
      body: text.isEmpty ? <String, Object?>{} : jsonDecode(text) as Map<String, Object?>,
    );
  }

  void check(bool success, String description) {
    if (!success) throw StateError(description);
    stdout.writeln('OK: $description');
  }

  Future<String> login(String username, String application) async {
    final response = await call(
      'POST',
      '/auth/login',
      body: {
        'username': username,
        'password': 'DemoPass123!',
        'application': application,
        'sessionTransport': 'bearer',
      },
    );
    check(response.status == 200, 'prijava $username');
    return response.body['token'] as String;
  }

  try {
    check((await call('GET', '/health')).status == 200, 'server i baza');
    final owner = await login('marko', 'mobile');
    final staff = await login('dispecer', 'backoffice');
    check((await call('GET', '/requests?scope=mine', token: owner)).status == 200, 'moji zahtevi');
    check((await call('GET', '/requests?scope=all', token: staff)).status == 200, 'dispečerski pregled');
    check(
      (await call('POST', '/requests/seed-1/assign', token: owner, body: {'washerId': 'w-1'})).status == 403,
      'klijent ne dodeljuje perača',
    );
    check(
      (await call('POST', '/requests/seed-3/release', token: owner, body: {})).status == 403,
      'klijent ne vraća zahtev u red',
    );
    check(
      (await call('POST', '/requests/seed-2/cancel', token: owner, body: {'reason': 'Tuđ zahtev'})).status == 403,
      'klijent ne otkazuje tuđ zahtev',
    );

    final now = DateTime.now().toUtc();
    final created = await call(
      'POST',
      '/requests',
      token: owner,
      body: {
        'vehicle': {'type': 'sedan', 'plate': 'BG 123-AB'},
        'tier': 'economy',
        'address': {'text': 'Knez Mihailova 6, Beograd'},
        'start': DateTime.utc(now.year, now.month, now.day + 1, 10).toIso8601String(),
        'note': 'Demo zahtev',
      },
    );
    check(created.status == 201, 'kreiranje zahteva');
    final createdId = (created.body['request'] as Map<String, Object?>)['id'] as String;
    check((await call('GET', '/requests/$createdId', token: staff)).status == 200, 'promena vidljiva drugoj ulozi');

    final assignments = await Future.wait([
      call('POST', '/requests/seed-1/assign', token: staff, body: {'washerId': 'w-1'}),
      call('POST', '/requests/seed-2/assign', token: staff, body: {'washerId': 'w-1'}),
    ]);
    check(
      assignments.where((response) => response.status == 200).length == 1 &&
          assignments.where((response) => response.status == 409 && response.body['code'] == 'washer_busy').length == 1,
      'dva istovremena poziva daju jednu dodelu',
    );
    final winner = assignments.singleWhere((response) => response.status == 200);
    final assignedId = (winner.body['request'] as Map<String, Object?>)['id'] as String;
    check(
      (await call('POST', '/requests/$assignedId/release', token: staff, body: {})).status == 200,
      'vraćanje u red',
    );
    check(
      (await call('POST', '/requests/$createdId/cancel', token: owner, body: {'reason': 'Završen demo'})).status == 200,
      'otkazivanje svog zahteva',
    );
    check((await call('POST', '/auth/logout', token: owner, body: {})).status == 204, 'odjava');
    check((await call('GET', '/auth/me', token: owner)).status == 401, 'odjavljeni token više ne važi');
  } finally {
    client.close(force: true);
  }
}
