import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:domain/domain.dart';
import 'package:http/http.dart' as http;
import 'package:use_cases/testing.dart';
import 'package:use_cases/use_cases.dart';

final baseUrl = Uri.parse(Platform.environment['API_BASE_URL'] ?? 'http://localhost:8080');
const password = String.fromEnvironment('DEMO_PASSWORD', defaultValue: 'DemoPass123!');

final class Client {
  Client(ClientApplication application, {SessionStorage? storage})
    : storage = storage ?? InMemorySessionStorage(),
      api = CarWashApi(
        baseUrl: baseUrl,
        client: http.Client(),
        session: SessionController(transport: SessionTransport.bearer),
      ) {
    auth = HttpAuthRepository(api: api, application: application, storage: this.storage);
    requests = HttpWashRequestRepository(api);
    washers = HttpWasherRepository(api);
  }

  final SessionStorage storage;
  final CarWashApi api;
  late final HttpAuthRepository auth;
  late final HttpWashRequestRepository requests;
  late final HttpWasherRepository washers;
}

void check(bool condition, String label) {
  if (!condition) {
    stderr.writeln('NIJE PROŠLO: $label');
    exit(1);
  }
  stdout.writeln('OK: $label');
}

Future<WashRequest?> findOnPages(WashRequestRepository requests, RequestQuery first, WashRequestId id) async {
  var query = first;
  while (true) {
    final page = await requests.list(query);
    final found = page.items.where((r) => r.id == id).firstOrNull;
    if (found != null || !page.hasNext) return found;
    query = RequestQuery(scope: query.scope, limit: query.limit, offset: page.nextOffset, status: query.status);
  }
}

WashRequestDraft draftFor(DateTime start, {String note = 'Provera klijentskog adaptera.'}) => WashRequestDraft(
  vehicle: Vehicle(type: VehicleType.sedan, plate: LicensePlate.parse('BG 765-KT').valueOrNull!),
  tier: ServiceTier.economy,
  address: Address.parse('Knez Mihailova 6, Beograd').valueOrNull!,
  slot: WashSlot.existing(start, const Duration(minutes: 45)),
  note: WashNote.existing(note),
);

Future<void> main() async {
  final offline = Client(ClientApplication.mobile);
  final unreachable = HttpAuthRepository(
    api: CarWashApi(
      baseUrl: baseUrl.replace(port: 1),
      client: http.Client(),
      session: offline.api.session,
      timeout: const Duration(seconds: 3),
    ),
    application: ClientApplication.mobile,
    storage: offline.storage,
  );
  try {
    await unreachable.login(username: 'marko', password: password);
    check(false, 'nedostupan server daje mrežnu grešku');
  } on NetworkException {
    check(true, 'nedostupan server daje mrežnu grešku');
  }

  final marko = Client(ClientApplication.mobile);
  final ana = Client(ClientApplication.mobile);
  final dispatcher = Client(ClientApplication.backoffice);
  await marko.auth.login(username: 'marko', password: password);
  await ana.auth.login(username: 'ana', password: password);
  await dispatcher.auth.login(username: 'dispecer', password: password);
  check(await marko.storage.read() != null, 'prijava klijenta i dispečera, token u skladištu');

  try {
    await Client(ClientApplication.backoffice).auth.login(username: 'marko', password: password);
    check(false, 'klijent ne ulazi u backoffice');
  } on LoginRejected catch (rejection) {
    check(rejection.reason == LoginFailure.wrongApplication, 'klijent ne ulazi u backoffice');
  }
  try {
    await Client(ClientApplication.mobile).auth.login(username: 'marko', password: 'pogresno');
    check(false, 'pogrešna lozinka');
  } on LoginRejected catch (rejection) {
    check(rejection.reason == LoginFailure.invalidCredentials, 'pogrešna lozinka nije istek sesije');
  }

  final tomorrow = inBusinessTime(DateTime.now().add(const Duration(days: 1)));
  final start = businessDate(tomorrow.year, tomorrow.month, tomorrow.day, 10, 30);
  final created = await marko.requests.create(draftFor(start));
  final request = created.valueOrNull;
  check(request != null, 'Marko kreira zahtev (${created.errorOrNull ?? 'prihvaćen'})');
  check(request!.clientId.value == 'u-client' && request.status is Submitted, 'vlasnik i stanje dolaze sa servera');

  final tooLong = await marko.requests.create(draftFor(start, note: 'a' * 301));
  check(switch (tooLong.errorOrNull) {
    NoteTooLong(:final maxLength) => maxLength == WashNote.maxLength,
    _ => false,
  }, 'napomena preko granice vraća granicu sa servera');

  final seen = await findOnPages(
    dispatcher.requests,
    const RequestQuery(scope: RequestScope.all, limit: 5, status: RequestStatusFilter.submitted),
    request.id,
  );
  check(seen != null, 'dispečer vidi novi zahtev kroz stranice i filter');
  check((await dispatcher.requests.find(request.id))?.id == request.id, 'detalj po ID-u nezavisno od stranice');
  check(await ana.requests.find(request.id) == null, 'Ana ne vidi Markov zahtev');
  check(
    await findOnPages(ana.requests, const RequestQuery(scope: RequestScope.mine), request.id) == null,
    'Markov zahtev nije na Aninoj listi',
  );

  check(
    (await marko.requests.assign(id: request.id, washerId: const WasherId('w-1'))).errorOrNull is NotAllowed,
    'klijent ne dodeljuje perača',
  );
  check((await marko.requests.release(id: request.id)).errorOrNull is NotAllowed, 'klijent ne vraća u red');
  check((await ana.requests.cancel(id: request.id, reason: 'x')).errorOrNull is NotAllowed, 'tuđe otkazivanje');

  final washers = await dispatcher.washers.washers();
  final free = washers.where((w) => !w.hasActiveJob).firstOrNull;
  check(free != null, 'perači i dostupnost sa servera (${washers.length})');
  final queue = await dispatcher.requests.list(
    const RequestQuery(scope: RequestScope.all, limit: 100, status: RequestStatusFilter.submitted),
  );
  final other = queue.items.where((r) => r.id != request.id).firstOrNull;
  check(other != null, 'postoji drugi zahtev u redu');
  final secondDispatcher = Client(ClientApplication.backoffice);
  await secondDispatcher.auth.login(username: 'dispecer', password: password);
  final results = await Future.wait([
    dispatcher.requests.assign(id: request.id, washerId: free!.id),
    secondDispatcher.requests.assign(id: other!.id, washerId: free.id),
  ]);
  final winners = results.where((r) => r.isSuccess).length;
  final busy = results.where((r) => r.errorOrNull is WasherBusy).length;
  check(winners == 1 && busy == 1, 'dva dispečera, isti perač: jedan uspeva, drugi dobija washer_busy');
  check(
    (await dispatcher.washers.washers()).firstWhere((w) => w.id == free.id).hasActiveJob,
    'osveženi perači pokazuju zauzetost',
  );
  final assigned = results[0].isSuccess ? request.id : other.id;
  if (assigned == request.id) {
    check((await marko.requests.find(request.id))?.status is Accepted, 'Marko vidi dodelu posle osvežavanja');
  }
  check((await dispatcher.requests.release(id: assigned)).valueOrNull?.status is Submitted, 'vraćanje u red');

  final restoredClient = Client(ClientApplication.mobile, storage: marko.storage);
  check((await restoredClient.auth.restore())?.user.username == 'marko', 'obnova prijave iz sačuvanog tokena');

  check(
    (await marko.requests.cancel(id: request.id, reason: 'Otkazao klijent.')).valueOrNull?.status is Cancelled,
    'klijent otkazuje svoj zahtev',
  );

  final expiredEvents = <void>[];
  restoredClient.api.session.expired.listen(expiredEvents.add);
  await marko.auth.logout();
  check(await marko.storage.read() == null, 'odjava briše token tek posle servera');
  try {
    await restoredClient.requests.list(const RequestQuery(scope: RequestScope.mine));
    check(false, 'opozvan token');
  } on SessionExpiredException {
    await Future<void>.delayed(Duration.zero);
    check(expiredEvents.length == 1, 'opozvan token daje istek sesije jednom');
  }
  check(
    await Client(ClientApplication.mobile, storage: marko.storage).auth.restore() == null,
    'posle odjave nema obnove',
  );

  await ana.auth.logout();
  await dispatcher.auth.logout();
  await secondDispatcher.auth.logout();
  exit(0);
}
