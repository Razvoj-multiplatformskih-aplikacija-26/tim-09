import 'package:bloc_test/bloc_test.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:use_cases/testing.dart';
import 'package:use_cases/use_cases.dart';

import 'fake_wash_requests.dart';

final now = businessDate(2026, 10, 26, 9);
const client = User(id: UserId('u-client'), username: 'marko', role: Role.client);
const other = User(id: UserId('u-other'), username: 'ana', role: Role.client);

WashRequest request(String id, {UserId? owner, int minutes = 0, WashStatus status = const Submitted()}) => WashRequest(
  id: WashRequestId(id),
  clientId: owner ?? client.id,
  vehicle: Vehicle(type: VehicleType.sedan, plate: LicensePlate.parse('BG 123-AB').valueOrNull!),
  tier: ServiceTier.economy,
  address: Address.parse('Knez Mihailova 6').valueOrNull!,
  slot: WashSlot.existing(now.add(Duration(days: 1, minutes: minutes)), const Duration(minutes: 45)),
  status: status,
  createdAt: now,
);

RequestDetailBloc blocFor(String id, InMemoryWashRequests repository, {bool withCancel = true}) => RequestDetailBloc(
  id: WashRequestId(id),
  getRequest: GetRequest(requests: repository),
  cancelRequest: withCancel ? CancelRequest(requests: repository) : null,
  clock: FixedClock(now),
  user: client,
);

void main() {
  final many = [for (var i = 0; i < 30; i++) request('wr-$i', minutes: 30 * i)];

  blocTest<RequestDetailBloc, RequestDetailState>(
    'zapis van prve stranice se čita po ID-u',
    build: () => blocFor('wr-29', fakeRequests(client, now, many)),
    act: (bloc) => bloc.add(const RequestDetailRequested()),
    expect: () => [const RequestDetailLoading(), RequestDetailLoaded(many.last, canCancel: true)],
  );

  blocTest<RequestDetailBloc, RequestDetailState>(
    'tuđ ili nepostojeći zapis → nedostupan',
    build: () => blocFor('foreign', fakeRequests(client, now, [request('foreign', owner: other.id)])),
    act: (bloc) => bloc.add(const RequestDetailRequested()),
    expect: () => [const RequestDetailLoading(), const RequestDetailUnavailable()],
  );

  blocTest<RequestDetailBloc, RequestDetailState>(
    'greška pa ponovni pokušaj',
    build: () => blocFor('wr-0', fakeRequests(client, now, many)..failingRequests = 1),
    act: (bloc) async {
      bloc.add(const RequestDetailRequested());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const RequestDetailRequested());
    },
    expect: () => [
      const RequestDetailLoading(),
      isA<RequestDetailFailure>(),
      const RequestDetailLoading(),
      RequestDetailLoaded(many.first, canCancel: true),
    ],
  );

  blocTest<RequestDetailBloc, RequestDetailState>(
    'otkazivanje sa detalja osvežava zapis i javlja ishod',
    build: () => blocFor('wr-0', fakeRequests(client, now, many)),
    seed: () => RequestDetailLoaded(many.first, canCancel: true),
    act: (bloc) => bloc.add(const RequestDetailCancelRequested(reason: 'Otkazao klijent.')),
    expect: () {
      final cancelled = many.first.copyWith(
        status: Cancelled(reason: 'Otkazao klijent.', cancelledBy: client.id, at: now),
      );
      return [
        RequestDetailLoaded(many.first, canCancel: true, cancelling: true),
        RequestDetailLoaded(cancelled, notice: RequestCancelled(cancelled)),
      ];
    },
  );

  blocTest<RequestDetailBloc, RequestDetailState>(
    'bez komande otkazivanja detalj je samo za čitanje',
    build: () => blocFor('wr-0', fakeRequests(client, now, many), withCancel: false),
    act: (bloc) => bloc.add(const RequestDetailRequested()),
    expect: () => [const RequestDetailLoading(), RequestDetailLoaded(many.first)],
  );
}
