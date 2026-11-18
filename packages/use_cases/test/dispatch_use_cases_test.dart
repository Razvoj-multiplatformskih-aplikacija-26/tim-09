import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:use_cases/testing.dart';
import 'package:use_cases/use_cases.dart';

final now = businessDate(2026, 10, 26, 9);
const dispatcher = User(id: UserId('u-dispatcher'), username: 'dispecer', role: Role.dispatcher);
const client = User(id: UserId('u-client'), username: 'marko', role: Role.client);
const washer = WasherId('w-1');
const washers = [
  Washer(id: WasherId('w-1'), name: 'Nikola Petrović', hasActiveJob: false),
  Washer(id: WasherId('w-2'), name: 'Jovan Ilić', hasActiveJob: false),
];

WashRequest request(String id, {WashStatus status = const Submitted()}) => WashRequest(
  id: WashRequestId(id),
  clientId: client.id,
  vehicle: Vehicle(type: VehicleType.sedan, plate: LicensePlate.parse('BG 123-AB').valueOrNull!),
  tier: ServiceTier.economy,
  address: Address.parse('Knez Mihailova 6').valueOrNull!,
  slot: WashSlot.existing(now.add(const Duration(days: 1)), const Duration(minutes: 45)),
  status: status,
  createdAt: now,
);

InMemoryWashRequests repositoryOf(List<WashRequest> requests, {User user = dispatcher}) =>
    InMemoryWashRequests(clock: FixedClock(now), currentUser: () => user, requests: requests, washers: washers);

void main() {
  group('AcceptRequest', () {
    test('slobodan perač: zahtev se čuva kao prihvaćen', () async {
      final requests = repositoryOf([request('wr-1')]);
      final result = await AcceptRequest(requests: requests)(id: const WashRequestId('wr-1'), washer: washer);
      expect(result.valueOrNull?.status, Accepted(washerId: washer, acceptedBy: dispatcher.id, at: now));
      expect(requests.writes, 1);
      expect((await requests.find(const WashRequestId('wr-1')))?.status, isA<Accepted>());
    });

    test('perač sa poslom u toku → WasherBusy, ništa se ne čuva', () async {
      final requests = repositoryOf([
        request('wr-1'),
        request(
          'wr-2',
          status: InProgress(washerId: washer, arrivedAt: now),
        ),
      ]);
      final result = await AcceptRequest(requests: requests)(id: const WashRequestId('wr-1'), washer: washer);
      expect(result.errorOrNull, const WasherBusy(washerId: washer));
      expect(requests.writes, 0);
    });

    test('nepostojeći zahtev ili perač → NotFound', () async {
      final requests = repositoryOf([request('wr-1')]);
      final accept = AcceptRequest(requests: requests);
      expect((await accept(id: const WashRequestId('nema'), washer: washer)).errorOrNull, isA<NotFound>());
      expect(
        (await accept(id: const WashRequestId('wr-1'), washer: const WasherId('w-9'))).errorOrNull,
        isA<NotFound>(),
      );
    });

    test('klijent ne može da dodeli perača', () async {
      final requests = repositoryOf([request('wr-1')], user: client);
      final result = await AcceptRequest(requests: requests)(id: const WashRequestId('wr-1'), washer: washer);
      expect(result.errorOrNull, isA<NotAllowed>());
    });
  });

  group('ReleaseRequest', () {
    test('prihvaćen zahtev se čuva kao prijavljen', () async {
      final requests = repositoryOf([
        request(
          'wr-1',
          status: Accepted(washerId: washer, acceptedBy: dispatcher.id, at: now),
        ),
      ]);
      final result = await ReleaseRequest(requests: requests)(id: const WashRequestId('wr-1'));
      expect(result.valueOrNull?.status, const Submitted());
      expect(requests.writes, 1);
    });

    test('prijavljen zahtev → InvalidTransition, ništa se ne čuva', () async {
      final requests = repositoryOf([request('wr-1')]);
      final result = await ReleaseRequest(requests: requests)(id: const WashRequestId('wr-1'));
      expect(result.errorOrNull, isA<InvalidTransition>());
      expect(requests.writes, 0);
    });
  });

  test('GetAllRequests vraća stranicu svih zahteva', () async {
    final all = [request('wr-1'), request('wr-2')];
    final page = await GetAllRequests(requests: repositoryOf(all))();
    expect(page.items, all);
    expect(page.limit, GetAllRequests.pageSize);
  });

  test('GetWashers računa dostupnost nad svim aktivnim poslovima', () async {
    final requests = repositoryOf([
      request(
        'wr-1',
        status: Accepted(washerId: washer, acceptedBy: dispatcher.id, at: now),
      ),
    ]);
    final result = await GetWashers(washers: requests)();
    expect({for (final w in result) w.id: w.hasActiveJob}, {washer: true, const WasherId('w-2'): false});
  });
}
