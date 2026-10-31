import 'package:bloc_test/bloc_test.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:use_cases/use_cases.dart';

import 'fake_wash_requests.dart';

final now = DateTime(2026, 10, 26, 9);
const dispatcher = User(id: UserId('u-disp'), username: 'dispečer', role: Role.dispatcher);
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

DispatchBloc blocWith(FakeWashRequests repository) => DispatchBloc(
  getAllRequests: GetAllRequests(requests: repository),
  acceptRequest: AcceptRequest(requests: repository),
  releaseRequest: ReleaseRequest(requests: repository),
  cancelRequest: CancelRequest(requests: repository, clock: FixedClock(now)),
  clock: FixedClock(now),
  dispatcher: dispatcher,
);

void main() {
  final pending = request('wr-1', start: now.add(const Duration(days: 1)));
  final accepted = request(
    'wr-2',
    start: now.add(const Duration(hours: 2)),
    status: Accepted(washerId: const WasherId('w-1'), acceptedBy: dispatcher.id, at: now),
  );

  blocTest<DispatchBloc, DispatchState>(
    'učitavanje svih zahteva → DispatchLoaded',
    build: () => blocWith(FakeWashRequests([pending, accepted])),
    act: (bloc) => bloc.add(const DispatchRequested()),
    expect: () => [
      const DispatchLoading(),
      DispatchLoaded(requests: [pending, accepted]),
    ],
  );

  blocTest<DispatchBloc, DispatchState>(
    'bez zahteva u sistemu → DispatchEmpty',
    build: () => blocWith(FakeWashRequests()),
    act: (bloc) => bloc.add(const DispatchRequested()),
    expect: () => [
      const DispatchLoading(),
      const DispatchEmpty(),
    ],
  );

  blocTest<DispatchBloc, DispatchState>(
    'selekcija zahteva čuva ID u stanju (DispatchRequestSelected)',
    build: () => blocWith(FakeWashRequests([pending])),
    seed: () => DispatchLoaded(requests: [pending]),
    act: (bloc) => bloc.add(const DispatchRequestSelected(WashRequestId('wr-1'))),
    expect: () => [
      DispatchLoaded(requests: [pending], selectedId: const WashRequestId('wr-1')),
    ],
  );

blocTest<DispatchBloc, DispatchState>(
    'prihvatanje zahteva od strane dispečera (AcceptRequested)',
    build: () => blocWith(FakeWashRequests([pending])),
    seed: () => DispatchLoaded(requests: [pending]),
    act: (bloc) => bloc.add(AcceptRequested(pending.id, const WasherId('w-2'))),
    expect: () {
      final updated = pending.copyWith(
        status: Accepted(washerId: const WasherId('w-2'), acceptedBy: dispatcher.id, at: now),
      );
      return [
        DispatchLoaded(requests: [pending], busyId: pending.id),
        DispatchLoaded(
          requests: [updated],
          notice: const DispatchActionSuccess('Zahtev je uspešno dodeljen peraču.'),
        ),
      ];
    },
  );
}