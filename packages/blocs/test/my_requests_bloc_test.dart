import 'package:bloc_test/bloc_test.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:use_cases/use_cases.dart';

import 'fake_wash_requests.dart';

final now = DateTime(2026, 10, 26, 9);
const client = User(id: UserId('u-client'), username: 'marko', role: Role.client);

WashRequest request(String id, {required DateTime start, WashStatus status = const Submitted()}) => WashRequest(
  id: WashRequestId(id),
  clientId: client.id,
  vehicle: Vehicle(type: VehicleType.sedan, plate: LicensePlate.parse('BG 123-AB').valueOrNull!),
  tier: ServiceTier.economy,
  address: Address.parse('Knez Mihailova 6').valueOrNull!,
  slot: WashSlot.existing(start, const Duration(minutes: 45)),
  status: status,
  createdAt: now,
);

MyRequestsBloc blocWith(FakeWashRequests repository) => MyRequestsBloc(
  getMyRequests: GetMyRequests(requests: repository),
  cancelRequest: CancelRequest(requests: repository, clock: FixedClock(now)),
  clock: FixedClock(now),
  client: client,
);

void main() {
  final upcoming = request('wr-1', start: now.add(const Duration(days: 1)));
  final soon = request(
    'wr-2',
    start: now.add(const Duration(minutes: 30)),
    status: Accepted(washerId: const WasherId('w-1'), acceptedBy: const UserId('u-d'), at: now),
  );
  final done = request('wr-3', start: now.subtract(const Duration(days: 1)), status: Completed(finishedAt: now));

  blocTest<MyRequestsBloc, MyRequestsState>(
    'učitavanje pa podaci; Bloc iz domena zna šta sme da se otkaže',
    build: () => blocWith(FakeWashRequests([upcoming, soon, done])),
    act: (bloc) => bloc.add(const MyRequestsRequested()),
    expect: () => [
      const MyRequestsLoading(),
      MyRequestsLoaded(active: [soon, upcoming], past: [done], cancellable: {upcoming.id}),
    ],
  );

  blocTest<MyRequestsBloc, MyRequestsState>(
    'bez zahteva → prazno',
    build: () => blocWith(FakeWashRequests()),
    act: (bloc) => bloc.add(const MyRequestsRequested()),
    expect: () => [const MyRequestsLoading(), const MyRequestsEmpty()],
  );

  blocTest<MyRequestsBloc, MyRequestsState>(
    'greška repozitorijuma → Failure, „Pokušaj ponovo“ → podaci',
    build: () => blocWith(FakeWashRequests([upcoming])..failingRequests = 1),
    act: (bloc) async {
      bloc.add(const MyRequestsRequested());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const MyRequestsRequested());
    },
    expect: () => [
      const MyRequestsLoading(),
      isA<MyRequestsFailure>(),
      const MyRequestsLoading(),
      MyRequestsLoaded(active: [upcoming], past: const [], cancellable: {upcoming.id}),
    ],
  );

  blocTest<MyRequestsBloc, MyRequestsState>(
    'otkazivanje: dugme zauzeto, pa lista sa otkazanim zahtevom i porukom',
    build: () => blocWith(FakeWashRequests([upcoming])),
    seed: () => MyRequestsLoaded(active: [upcoming], past: const [], cancellable: {upcoming.id}),
    act: (bloc) => bloc.add(RequestCancellationRequested(upcoming.id, reason: 'Otkazao klijent.')),
    expect: () {
      final cancelled = upcoming.copyWith(
        status: Cancelled(reason: 'Otkazao klijent.', cancelledBy: client.id, at: now),
      );
      return [
        MyRequestsLoaded(active: [upcoming], past: const [], cancellable: {upcoming.id}, cancellingId: upcoming.id),
        MyRequestsLoaded(active: const [], past: [cancelled], cancellable: const {}, notice: RequestCancelled(cancelled)),
      ];
    },
  );

  blocTest<MyRequestsBloc, MyRequestsState>(
    'prekasno otkazivanje → poruka CancellationRejected(CancellationTooLate)',
    build: () => blocWith(FakeWashRequests([soon])),
    seed: () => MyRequestsLoaded(active: [soon], past: const [], cancellable: const {}),
    act: (bloc) => bloc.add(RequestCancellationRequested(soon.id)),
    skip: 1,
    expect: () => [
      MyRequestsLoaded(
        active: [soon],
        past: const [],
        cancellable: const {},
        notice: const CancellationRejected(CancellationTooLate()),
      ),
    ],
  );
}
