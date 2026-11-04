import 'package:bloc_test/bloc_test.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:use_cases/use_cases.dart';

import 'fake_wash_requests.dart';

final now = DateTime(2026, 10, 26, 9);
const dispatcher = User(id: UserId('u-dispatcher'), username: 'dispečer', role: Role.dispatcher);
const client = User(id: UserId('u-client'), username: 'marko', role: Role.client);
const washer = WasherId('w-1');
const otherWasher = WasherId('w-2');

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

DispatchBloc blocWith(FakeWashRequests repository) => DispatchBloc(
  getAllRequests: GetAllRequests(requests: repository),
  acceptRequest: AcceptRequest(requests: repository),
  releaseRequest: ReleaseRequest(requests: repository),
  cancelRequest: CancelRequest(requests: repository, clock: FixedClock(now)),
  clock: FixedClock(now),
  dispatcher: dispatcher,
);

void main() {
  final pending = request('wr-1');
  final taken = request(
    'wr-2',
    status: Accepted(washerId: washer, acceptedBy: dispatcher.id, at: now),
  );
  final running = request(
    'wr-3',
    status: InProgress(washerId: washer, arrivedAt: now),
  );

  group('učitavanje', () {
    blocTest<DispatchBloc, DispatchState>(
      'svi zahtevi → Loaded',
      build: () => blocWith(FakeWashRequests([pending, taken])),
      act: (bloc) => bloc.add(const DispatchRequested()),
      expect: () => [
        const DispatchLoading(),
        DispatchLoaded(requests: [pending, taken]),
      ],
    );

    blocTest<DispatchBloc, DispatchState>(
      'bez zahteva → Empty',
      build: () => blocWith(FakeWashRequests()),
      act: (bloc) => bloc.add(const DispatchRequested()),
      expect: () => [const DispatchLoading(), const DispatchEmpty()],
    );

    blocTest<DispatchBloc, DispatchState>(
      'greška repozitorijuma → Failure, „Pokušaj ponovo“ → podaci',
      build: () => blocWith(FakeWashRequests([pending])..failingRequests = 1),
      act: (bloc) async {
        bloc.add(const DispatchRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const DispatchRequested());
      },
      expect: () => [
        const DispatchLoading(),
        isA<DispatchFailure>(),
        const DispatchLoading(),
        DispatchLoaded(requests: [pending]),
      ],
    );
  });

  group('izbor', () {
    blocTest<DispatchBloc, DispatchState>(
      'izbor pa poništavanje',
      build: () => blocWith(FakeWashRequests([pending])),
      seed: () => DispatchLoaded(requests: [pending]),
      act: (bloc) => bloc
        ..add(DispatchRequestSelected(pending.id))
        ..add(const DispatchRequestSelected(null)),
      expect: () => [
        DispatchLoaded(requests: [pending], selectedId: pending.id),
        DispatchLoaded(requests: [pending]),
      ],
    );

    blocTest<DispatchBloc, DispatchState>(
      'izbor preživljava osvežavanje ako je zahtev i dalje u listi',
      build: () => blocWith(FakeWashRequests([pending])),
      seed: () => DispatchLoaded(requests: [pending], selectedId: pending.id),
      act: (bloc) => bloc.add(const DispatchRequested()),
      expect: () => [
        const DispatchLoading(),
        DispatchLoaded(requests: [pending], selectedId: pending.id),
      ],
    );

    blocTest<DispatchBloc, DispatchState>(
      'izbor nestaje ako zahteva posle osvežavanja više nema',
      build: () => blocWith(FakeWashRequests([pending])),
      seed: () => DispatchLoaded(requests: [pending, taken], selectedId: taken.id),
      act: (bloc) => bloc.add(const DispatchRequested()),
      expect: () => [
        const DispatchLoading(),
        DispatchLoaded(requests: [pending]),
      ],
    );

    blocTest<DispatchBloc, DispatchState>(
      'posle radnje izabrani zahtev ostaje izabran',
      build: () => blocWith(FakeWashRequests([pending])),
      seed: () => DispatchLoaded(requests: [pending], selectedId: pending.id),
      act: (bloc) => bloc.add(DispatchAcceptRequested(pending.id, washer)),
      skip: 1,
      expect: () {
        final assigned = pending.copyWith(
          status: Accepted(washerId: washer, acceptedBy: dispatcher.id, at: now),
        );
        return [
          DispatchLoaded(requests: [assigned], selectedId: pending.id, notice: RequestAssigned(assigned)),
        ];
      },
    );
  });

  group('dodela perača', () {
    blocTest<DispatchBloc, DispatchState>(
      'slobodan perač: zahtev zauzet, pa lista sa prihvaćenim zahtevom i porukom',
      build: () => blocWith(FakeWashRequests([pending])),
      seed: () => DispatchLoaded(requests: [pending]),
      act: (bloc) => bloc.add(DispatchAcceptRequested(pending.id, washer)),
      expect: () {
        final assigned = pending.copyWith(
          status: Accepted(washerId: washer, acceptedBy: dispatcher.id, at: now),
        );
        return [
          DispatchLoaded(requests: [pending], busyId: pending.id),
          DispatchLoaded(requests: [assigned], notice: RequestAssigned(assigned)),
        ];
      },
    );

    for (final (label, busy) in [('prihvaćen', taken), ('u toku', running)]) {
      blocTest<DispatchBloc, DispatchState>(
        'perač sa poslom koji je $label → WasherBusy, lista se ne menja',
        build: () => blocWith(FakeWashRequests([pending, busy])),
        seed: () => DispatchLoaded(requests: [pending, busy]),
        act: (bloc) => bloc.add(DispatchAcceptRequested(pending.id, washer)),
        expect: () => [
          DispatchLoaded(requests: [pending, busy], busyId: pending.id),
          DispatchLoaded(requests: [pending, busy], notice: const DispatchActionRejected(WasherBusy())),
        ],
      );
    }

    blocTest<DispatchBloc, DispatchState>(
      'drugi perač je slobodan iako je prvi zauzet',
      build: () => blocWith(FakeWashRequests([pending, running])),
      seed: () => DispatchLoaded(requests: [pending, running]),
      act: (bloc) => bloc.add(DispatchAcceptRequested(pending.id, otherWasher)),
      skip: 1,
      expect: () => [isA<DispatchLoaded>().having((s) => s.notice, 'notice', isA<RequestAssigned>())],
    );

    blocTest<DispatchBloc, DispatchState>(
      'već prihvaćen zahtev se ne dodeljuje ponovo → InvalidTransition',
      build: () => blocWith(FakeWashRequests([taken])),
      seed: () => DispatchLoaded(requests: [taken]),
      act: (bloc) => bloc.add(DispatchAcceptRequested(taken.id, otherWasher)),
      skip: 1,
      expect: () => [
        isA<DispatchLoaded>().having(
          (s) => s.notice,
          'notice',
          isA<DispatchActionRejected>().having((n) => n.error, 'error', isA<InvalidTransition>()),
        ),
      ],
    );

    blocTest<DispatchBloc, DispatchState>(
      'dok radnja traje, drugi klik se ignoriše',
      build: () => blocWith(FakeWashRequests([pending])),
      seed: () => DispatchLoaded(requests: [pending]),
      act: (bloc) => bloc
        ..add(DispatchAcceptRequested(pending.id, washer))
        ..add(DispatchAcceptRequested(pending.id, otherWasher)),
      expect: () {
        final assigned = pending.copyWith(
          status: Accepted(washerId: washer, acceptedBy: dispatcher.id, at: now),
        );
        return [
          DispatchLoaded(requests: [pending], busyId: pending.id),
          DispatchLoaded(requests: [assigned], notice: RequestAssigned(assigned)),
        ];
      },
    );

    blocTest<DispatchBloc, DispatchState>(
      'greška repozitorijuma pri radnji → DispatchActionFailed, lista ostaje',
      build: () => blocWith(FakeWashRequests([pending])..failingRequests = 1),
      seed: () => DispatchLoaded(requests: [pending]),
      act: (bloc) => bloc.add(DispatchAcceptRequested(pending.id, washer)),
      expect: () => [
        DispatchLoaded(requests: [pending], busyId: pending.id),
        isA<DispatchLoaded>()
            .having((s) => s.requests, 'requests', [pending])
            .having((s) => s.busyId, 'busyId', isNull)
            .having((s) => s.notice, 'notice', isA<DispatchActionFailed>()),
      ],
    );
  });

  group('vraćanje u red i otkazivanje', () {
    blocTest<DispatchBloc, DispatchState>(
      'prihvaćen zahtev se vraća u Prijavljen',
      build: () => blocWith(FakeWashRequests([taken])),
      seed: () => DispatchLoaded(requests: [taken]),
      act: (bloc) => bloc.add(DispatchReleaseRequested(taken.id)),
      skip: 1,
      expect: () {
        final released = taken.copyWith(status: const Submitted());
        return [
          DispatchLoaded(requests: [released], notice: RequestReleased(released)),
        ];
      },
    );

    blocTest<DispatchBloc, DispatchState>(
      'prijavljen zahtev ne može da se vrati u red → InvalidTransition',
      build: () => blocWith(FakeWashRequests([pending])),
      seed: () => DispatchLoaded(requests: [pending]),
      act: (bloc) => bloc.add(DispatchReleaseRequested(pending.id)),
      skip: 1,
      expect: () => [
        isA<DispatchLoaded>().having(
          (s) => s.notice,
          'notice',
          isA<DispatchActionRejected>().having((n) => n.error, 'error', isA<InvalidTransition>()),
        ),
      ],
    );

    blocTest<DispatchBloc, DispatchState>(
      'dispečer otkazuje i zahtev u toku; razlog se čuva',
      build: () => blocWith(FakeWashRequests([running])),
      seed: () => DispatchLoaded(requests: [running]),
      act: (bloc) => bloc.add(DispatchCancelRequested(running.id, reason: 'Otkazao dispečer.')),
      skip: 1,
      expect: () {
        final cancelled = running.copyWith(
          status: Cancelled(reason: 'Otkazao dispečer.', cancelledBy: dispatcher.id, at: now),
        );
        return [
          DispatchLoaded(requests: [cancelled], notice: RequestCancelledByStaff(cancelled)),
        ];
      },
    );
  });

  blocTest<DispatchBloc, DispatchState>(
    'potvrđena poruka se briše iz stanja',
    build: () => blocWith(FakeWashRequests([pending])),
    seed: () => DispatchLoaded(requests: [pending], notice: RequestAssigned(pending)),
    act: (bloc) => bloc.add(const DispatchNoticeAcknowledged()),
    expect: () => [
      DispatchLoaded(requests: [pending]),
    ],
  );
}
