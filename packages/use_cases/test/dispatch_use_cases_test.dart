import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:use_cases/use_cases.dart';

final now = DateTime(2026, 10, 26, 9);
const dispatcher = User(id: UserId('u-dispatcher'), username: 'dispečer', role: Role.dispatcher);
const washer = WasherId('w-1');

WashRequest request(String id, {WashStatus status = const Submitted()}) => WashRequest(
  id: WashRequestId(id),
  clientId: const UserId('u-client'),
  vehicle: Vehicle(type: VehicleType.sedan, plate: LicensePlate.parse('BG 123-AB').valueOrNull!),
  tier: ServiceTier.economy,
  address: Address.parse('Knez Mihailova 6').valueOrNull!,
  slot: WashSlot.existing(now.add(const Duration(days: 1)), const Duration(minutes: 45)),
  status: status,
  createdAt: now,
);

/// Repozitorijum u memoriji koji broji čuvanja, da test vidi da odbijena radnja ništa ne upisuje.
final class _Requests implements WashRequestRepository {
  _Requests(List<WashRequest> requests) : _requests = [...requests];

  final List<WashRequest> _requests;
  int saves = 0;

  @override
  Future<List<WashRequest>> allRequests() async => List.of(_requests);

  @override
  Future<WashRequest?> find(WashRequestId id) async => _requests.where((r) => r.id == id).firstOrNull;

  @override
  Future<WashRequest> save(WashRequest request) async {
    saves++;
    _requests[_requests.indexWhere((r) => r.id == request.id)] = request;
    return request;
  }

  @override
  Future<List<WashRequest>> requestsOf(UserId clientId) => throw UnimplementedError();

  @override
  Future<WashRequest> create(WashRequestDraft draft) => throw UnimplementedError();
}

void main() {
  group('AcceptRequest', () {
    test('slobodan perač: zahtev se čuva kao prihvaćen', () async {
      final requests = _Requests([request('wr-1')]);
      final result = await AcceptRequest(requests: requests)(
        id: const WashRequestId('wr-1'),
        washer: washer,
        by: dispatcher,
        now: now,
      );
      expect(result.valueOrNull?.status, Accepted(washerId: washer, acceptedBy: dispatcher.id, at: now));
      expect(requests.saves, 1);
      expect((await requests.find(const WashRequestId('wr-1')))?.status, isA<Accepted>());
    });

    test('perač sa poslom u toku → WasherBusy, ništa se ne čuva', () async {
      final requests = _Requests([
        request('wr-1'),
        request(
          'wr-2',
          status: InProgress(washerId: washer, arrivedAt: now),
        ),
      ]);
      final result = await AcceptRequest(requests: requests)(
        id: const WashRequestId('wr-1'),
        washer: washer,
        by: dispatcher,
        now: now,
      );
      expect(result.errorOrNull, isA<WasherBusy>());
      expect(requests.saves, 0);
    });

    test('nepostojeći zahtev → NotFound', () async {
      final result = await AcceptRequest(requests: _Requests([]))(
        id: const WashRequestId('nema'),
        washer: washer,
        by: dispatcher,
        now: now,
      );
      expect(result.errorOrNull, isA<NotFound>());
    });
  });

  group('ReleaseRequest', () {
    test('prihvaćen zahtev se čuva kao prijavljen', () async {
      final requests = _Requests([
        request(
          'wr-1',
          status: Accepted(washerId: washer, acceptedBy: dispatcher.id, at: now),
        ),
      ]);
      final result = await ReleaseRequest(requests: requests)(id: const WashRequestId('wr-1'), by: dispatcher);
      expect(result.valueOrNull?.status, const Submitted());
      expect(requests.saves, 1);
    });

    test('prijavljen zahtev → InvalidTransition, ništa se ne čuva', () async {
      final requests = _Requests([request('wr-1')]);
      final result = await ReleaseRequest(requests: requests)(id: const WashRequestId('wr-1'), by: dispatcher);
      expect(result.errorOrNull, isA<InvalidTransition>());
      expect(requests.saves, 0);
    });

    test('nepostojeći zahtev → NotFound', () async {
      final result = await ReleaseRequest(requests: _Requests([]))(id: const WashRequestId('nema'), by: dispatcher);
      expect(result.errorOrNull, isA<NotFound>());
    });
  });

  test('GetAllRequests vraća sve zahteve, bez obzira na klijenta', () async {
    final all = [request('wr-1'), request('wr-2')];
    expect(await GetAllRequests(requests: _Requests(all))(), all);
  });
}
