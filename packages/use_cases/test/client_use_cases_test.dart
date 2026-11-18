import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:use_cases/testing.dart';
import 'package:use_cases/use_cases.dart';

final now = businessDate(2026, 10, 26, 9);
const client = User(id: UserId('u-client'), username: 'marko', role: Role.client);
const other = User(id: UserId('u-other'), username: 'ana', role: Role.client);
const washerUser = User(id: UserId('u-washer-1'), username: 'nikola', role: Role.washer, washerId: WasherId('w-1'));

WashRequest request(String id, {UserId? clientId, required DateTime start, WashStatus status = const Submitted()}) =>
    WashRequest(
      id: WashRequestId(id),
      clientId: clientId ?? client.id,
      vehicle: Vehicle(type: VehicleType.sedan, plate: LicensePlate.parse('BG 123-AB').valueOrNull!),
      tier: ServiceTier.economy,
      address: Address.parse('Knez Mihailova 6').valueOrNull!,
      slot: WashSlot.existing(start, const Duration(minutes: 45)),
      status: status,
      createdAt: now,
    );

WashRequestDraft draft() => WashRequestDraft(
  vehicle: Vehicle(type: VehicleType.suv, plate: LicensePlate.parse('NS 4521-KM').valueOrNull!),
  tier: ServiceTier.professional,
  address: Address.parse('Bulevar oslobođenja 15').valueOrNull!,
  slot: WashSlot.parse(businessDate(2026, 10, 27, 10), duration: const Duration(hours: 2), now: now).valueOrNull!,
  note: WashNote.parse('Garaža, nivo -2').valueOrNull,
);

InMemoryWashRequests repositoryOf(List<WashRequest> requests, {User user = client}) =>
    InMemoryWashRequests(clock: FixedClock(now), currentUser: () => user, requests: requests);

void main() {
  final tomorrow = businessDate(2026, 10, 27, 10);

  group('SubmitRequest', () {
    test('nacrt postaje prijavljen zahtev prijavljenog klijenta', () async {
      final requests = repositoryOf([]);
      final created = (await SubmitRequest(requests: requests)(draft())).valueOrNull!;
      expect(created.status, const Submitted());
      expect(created.clientId, client.id);
      expect(created.vehicle.plate.value, 'NS 4521-KM');
      expect(created.note?.text, 'Garaža, nivo -2');
      expect(created.price.priceRsd, 3500);
      expect(await requests.find(created.id), created);
    });

    test('odluku o granici zahteva na čekanju vraća adapter, ne lista na klijentu', () async {
      final requests = repositoryOf([
        request('a', start: tomorrow),
        request(
          'b',
          start: tomorrow,
          status: Accepted(washerId: const WasherId('w-1'), acceptedBy: other.id, at: now),
        ),
        request(
          'd',
          start: tomorrow,
          status: Completed(finishedAt: now),
        ),
        request('e', start: tomorrow, clientId: other.id),
      ]);
      expect((await SubmitRequest(requests: requests)(draft())).isSuccess, isTrue);
      final rejected = await SubmitRequest(requests: requests)(draft());
      expect(rejected.errorOrNull, const TooManyPendingRequests(currentPending: 3));
      expect(requests.writes, 1);
    });
  });

  group('GetMyRequests', () {
    test('vraća stranicu zahteva prijavljenog klijenta, po terminu', () async {
      final requests = repositoryOf([
        request('later', start: tomorrow.add(const Duration(days: 2))),
        request('foreign', start: tomorrow, clientId: other.id),
        request('sooner', start: tomorrow),
      ]);
      final page = await GetMyRequests(requests: requests)();
      expect(page.items.map((r) => r.id.value), ['sooner', 'later']);
      expect(page.total, 2);
      expect(page.limit, GetMyRequests.pageSize);
    });

    test('paginacija i filter stanja', () async {
      final requests = repositoryOf([
        for (var i = 0; i < 5; i++) request('r$i', start: tomorrow.add(Duration(hours: i))),
        request(
          'done',
          start: tomorrow.add(const Duration(days: 3)),
          status: Completed(finishedAt: now),
        ),
      ]);
      final second = await GetMyRequests(requests: requests)(offset: 2, limit: 2);
      expect(second.items.map((r) => r.id.value), ['r2', 'r3']);
      expect(second.total, 6);
      expect(second.hasPrevious, isTrue);
      expect(second.hasNext, isTrue);
      final done = await GetMyRequests(requests: requests)(status: RequestStatusFilter.completed);
      expect(done.items.map((r) => r.id.value), ['done']);
    });

    test('perač vidi samo svoje aktivne dodeljene poslove', () async {
      final requests = repositoryOf(user: washerUser, [
        request(
          'mine',
          start: tomorrow,
          status: Accepted(washerId: washerUser.washerId!, acceptedBy: other.id, at: now),
        ),
        request(
          'other',
          start: tomorrow,
          status: Accepted(washerId: const WasherId('w-2'), acceptedBy: other.id, at: now),
        ),
        request('queue', start: tomorrow),
      ]);
      final page = await GetMyRequests(requests: requests)();
      expect(page.items.map((r) => r.id.value), ['mine']);
    });
  });

  test('GetRequest čita detalj nezavisno od stranice i ne otkriva tuđi zapis', () async {
    final requests = repositoryOf([
      for (var i = 0; i < 30; i++) request('r$i', start: tomorrow.add(Duration(minutes: 30 * i))),
      request('foreign', start: tomorrow, clientId: other.id),
    ]);
    expect((await GetRequest(requests: requests)(const WashRequestId('r29')))?.id.value, 'r29');
    expect(await GetRequest(requests: requests)(const WashRequestId('foreign')), isNull);
    expect(await GetRequest(requests: requests)(const WashRequestId('nema')), isNull);
  });

  group('CancelRequest', () {
    test('otkazan zahtev nosi razlog, aktera iz sesije i vreme adaptera', () async {
      final requests = repositoryOf([request('a', start: tomorrow)]);
      final result = await CancelRequest(requests: requests)(id: const WashRequestId('a'), reason: 'Promena plana.');
      expect(result.valueOrNull?.status, Cancelled(reason: 'Promena plana.', cancelledBy: client.id, at: now));
      expect(requests.writes, 1);
    });

    test('tuđi zahtev → NotAllowed, nepostojeći → NotFound, ništa se ne upisuje', () async {
      final requests = repositoryOf([request('a', start: tomorrow, clientId: other.id)]);
      final cancel = CancelRequest(requests: requests);
      expect((await cancel(id: const WashRequestId('a'))).errorOrNull, isA<NotAllowed>());
      expect((await cancel(id: const WashRequestId('nema'))).errorOrNull, isA<NotFound>());
      expect(requests.writes, 0);
    });
  });

  test('bez sesije adapter javlja istek prijave', () async {
    final requests = InMemoryWashRequests(clock: FixedClock(now), currentUser: () => null);
    expect(() => GetMyRequests(requests: requests)(), throwsA(isA<SessionExpiredException>()));
  });

  test('stranica zna poslednji važeći pomeraj', () {
    final page = RequestPage(items: const [], total: 41, limit: 20, offset: 60);
    expect(page.isPastEnd, isTrue);
    expect(page.lastOffset, 40);
  });
}
