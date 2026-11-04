import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:use_cases/use_cases.dart';

final now = DateTime(2026, 10, 26, 9);
const client = User(id: UserId('u-client'), username: 'marko', role: Role.client);
const other = User(id: UserId('u-other'), username: 'ana', role: Role.client);

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
  clientId: client.id,
  vehicle: Vehicle(type: VehicleType.suv, plate: LicensePlate.parse('NS 4521-KM').valueOrNull!),
  tier: ServiceTier.professional,
  address: Address.parse('Bulevar oslobođenja 15').valueOrNull!,
  slot: WashSlot.parse(DateTime(2026, 10, 27, 10), duration: const Duration(hours: 2), now: now).valueOrNull!,
  note: WashNote.parse('Garaža, nivo -2').valueOrNull,
);

/// Repozitorijum u memoriji koji broji upise, da test vidi da odbijena radnja ništa ne menja.
final class _Requests implements WashRequestRepository {
  _Requests([List<WashRequest> requests = const []]) : _requests = [...requests];

  final List<WashRequest> _requests;
  int writes = 0;

  @override
  Future<List<WashRequest>> requestsOf(UserId clientId) async =>
      _requests.where((r) => r.clientId == clientId).toList();

  @override
  Future<WashRequest?> find(WashRequestId id) async => _requests.where((r) => r.id == id).firstOrNull;

  @override
  Future<WashRequest> create(WashRequestDraft draft) async {
    writes++;
    final created = WashRequest(
      id: WashRequestId('new-${_requests.length}'),
      clientId: draft.clientId,
      vehicle: draft.vehicle,
      tier: draft.tier,
      address: draft.address,
      slot: draft.slot,
      note: draft.note,
      createdAt: now,
    );
    _requests.add(created);
    return created;
  }

  @override
  Future<WashRequest> save(WashRequest request) async {
    writes++;
    _requests[_requests.indexWhere((r) => r.id == request.id)] = request;
    return request;
  }

  @override
  Future<List<WashRequest>> allRequests() async => List.of(_requests);
}

void main() {
  final tomorrow = DateTime(2026, 10, 27, 10);

  group('SubmitRequest', () {
    test('nacrt postaje prijavljen zahtev sa svim podacima', () async {
      final requests = _Requests();
      final created = (await SubmitRequest(requests: requests)(draft())).valueOrNull!;
      expect(created.status, const Submitted());
      expect(created.clientId, client.id);
      expect(created.vehicle.plate.value, 'NS 4521-KM');
      expect(created.note?.text, 'Garaža, nivo -2');
      expect(created.price.priceRsd, 3500);
      expect(await requests.find(created.id), created);
    });

    test('R6 broji prijavljene i prihvaćene zahteve tog klijenta, ne završene ni tuđe', () async {
      final requests = _Requests([
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
      expect(rejected.errorOrNull, isA<TooManyPendingRequests>());
      expect(requests.writes, 1);
    });
  });

  test('GetMyRequests vraća samo zahteve klijenta, po terminu', () async {
    final requests = _Requests([
      request('later', start: tomorrow.add(const Duration(days: 2))),
      request('foreign', start: tomorrow, clientId: other.id),
      request('sooner', start: tomorrow),
    ]);
    final mine = await GetMyRequests(requests: requests)(client);
    expect(mine.map((r) => r.id.value), ['sooner', 'later']);
  });

  group('CancelRequest', () {
    test('otkazan zahtev se čuva sa vremenom iz sata i razlogom', () async {
      final requests = _Requests([request('a', start: tomorrow)]);
      final result = await CancelRequest(requests: requests, clock: FixedClock(now))(
        id: const WashRequestId('a'),
        by: client,
        reason: 'Promena plana.',
      );
      expect(result.valueOrNull?.status, Cancelled(reason: 'Promena plana.', cancelledBy: client.id, at: now));
      expect(requests.writes, 1);
    });

    test('tuđi zahtev → NotAllowed, nepostojeći → NotFound, ništa se ne upisuje', () async {
      final requests = _Requests([request('a', start: tomorrow, clientId: other.id)]);
      final cancel = CancelRequest(requests: requests, clock: FixedClock(now));
      expect((await cancel(id: const WashRequestId('a'), by: client)).errorOrNull, isA<NotAllowed>());
      expect((await cancel(id: const WashRequestId('nema'), by: client)).errorOrNull, isA<NotFound>());
      expect(requests.writes, 0);
    });
  });
}
