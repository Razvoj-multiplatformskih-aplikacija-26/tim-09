import 'package:bloc_test/bloc_test.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:use_cases/testing.dart';
import 'package:use_cases/use_cases.dart';

import 'fake_wash_requests.dart';

final now = businessDate(2026, 10, 26, 9);
const dispatcher = User(id: UserId('u-dispatcher'), username: 'dispecer', role: Role.dispatcher);
const client = User(id: UserId('u-client'), username: 'marko', role: Role.client);
const washer = WasherId('w-1');
const otherWasher = WasherId('w-2');

WashRequest request(String id, {WashStatus status = const Submitted(), int hour = 0}) => WashRequest(
  id: WashRequestId(id),
  clientId: client.id,
  vehicle: Vehicle(type: VehicleType.sedan, plate: LicensePlate.parse('BG 123-AB').valueOrNull!),
  tier: ServiceTier.economy,
  address: Address.parse('Knez Mihailova 6').valueOrNull!,
  slot: WashSlot.existing(now.add(Duration(days: 1, hours: hour)), const Duration(minutes: 45)),
  status: status,
  createdAt: now,
);

List<Washer> washersFor(List<WashRequest> requests) => [
  for (final w in washerProfiles) Washer(id: w.id, name: w.name, hasActiveJob: washerHasActiveJob(w.id, requests)),
];

DispatchLoaded loaded(
  List<WashRequest> requests, {
  List<WashRequest>? all,
  WashRequestId? selectedId,
  WashRequestId? busyId,
  DispatchNotice? notice,
  RequestStatusFilter? filter,
}) => DispatchLoaded(
  page: pageOf(requests, limit: 50),
  washers: washersFor(all ?? requests),
  filter: filter,
  selectedId: selectedId,
  busyId: busyId,
  notice: notice,
);

DispatchBloc blocWith(InMemoryWashRequests repository) => DispatchBloc(
  getAllRequests: GetAllRequests(requests: repository),
  getWashers: GetWashers(washers: repository),
  acceptRequest: AcceptRequest(requests: repository),
  releaseRequest: ReleaseRequest(requests: repository),
  cancelRequest: CancelRequest(requests: repository),
);

InMemoryWashRequests repo(List<WashRequest> requests) => fakeRequests(dispatcher, now, requests);

void main() {
  final pending = request('wr-1');
  final taken = request(
    'wr-2',
    status: Accepted(washerId: washer, acceptedBy: dispatcher.id, at: now),
    hour: 1,
  );
  final running = request(
    'wr-3',
    status: InProgress(washerId: washer, arrivedAt: now),
    hour: 2,
  );

  group('učitavanje', () {
    blocTest<DispatchBloc, DispatchState>(
      'stranica zahteva i perači sa servera → Loaded',
      build: () => blocWith(repo([pending, taken])),
      act: (bloc) => bloc.add(const DispatchRequested()),
      expect: () => [
        const DispatchLoading(),
        loaded([pending, taken]),
      ],
      verify: (bloc) {
        final state = bloc.state as DispatchLoaded;
        expect(state.isWasherBusy(washer), isTrue);
        expect(state.isWasherBusy(otherWasher), isFalse);
        expect(state.washerName(washer), 'Nikola Petrović');
      },
    );

    blocTest<DispatchBloc, DispatchState>(
      'bez zahteva → Empty',
      build: () => blocWith(repo([])),
      act: (bloc) => bloc.add(const DispatchRequested()),
      expect: () => [const DispatchLoading(), const DispatchEmpty()],
    );

    blocTest<DispatchBloc, DispatchState>(
      'greška → Failure, „Pokušaj ponovo“ → podaci',
      build: () => blocWith(repo([pending])..failingRequests = 1),
      act: (bloc) async {
        bloc.add(const DispatchRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const DispatchRequested());
      },
      expect: () => [
        const DispatchLoading(),
        isA<DispatchFailure>(),
        const DispatchLoading(),
        loaded([pending]),
      ],
    );

    blocTest<DispatchBloc, DispatchState>(
      'filter stanja ide serveru i vraća na prvu stranicu',
      build: () => blocWith(repo([pending, taken, running])),
      act: (bloc) => bloc.add(const DispatchFilterChanged(RequestStatusFilter.accepted)),
      expect: () => [
        const DispatchLoading(filter: RequestStatusFilter.accepted),
        loaded([taken], all: [pending, taken, running], filter: RequestStatusFilter.accepted),
      ],
    );

    blocTest<DispatchBloc, DispatchState>(
      'dostupnost perača ne zavisi od trenutne stranice',
      build: () => blocWith(repo([pending, running])),
      act: (bloc) => bloc.add(const DispatchFilterChanged(RequestStatusFilter.submitted)),
      skip: 1,
      verify: (bloc) {
        final state = bloc.state as DispatchLoaded;
        expect(state.requests, [pending]);
        expect(state.isWasherBusy(washer), isTrue);
      },
    );

    blocTest<DispatchBloc, DispatchState>(
      'stranica van opsega učitava poslednju važeću',
      build: () =>
          blocWith(repo([for (var i = 0; i < 60; i++) request('wr-${i.toString().padLeft(2, '0')}', hour: 0)])),
      act: (bloc) => bloc.add(const DispatchPageRequested(150)),
      skip: 1,
      verify: (bloc) {
        final state = bloc.state as DispatchLoaded;
        expect((state.page.offset, state.page.total, state.requests.length), (50, 60, 10));
      },
    );
  });

  group('izbor', () {
    blocTest<DispatchBloc, DispatchState>(
      'izbor pa poništavanje',
      build: () => blocWith(repo([pending])),
      seed: () => loaded([pending]),
      act: (bloc) => bloc
        ..add(DispatchRequestSelected(pending.id))
        ..add(const DispatchRequestSelected(null)),
      expect: () => [
        loaded([pending], selectedId: pending.id),
        loaded([pending]),
      ],
    );

    blocTest<DispatchBloc, DispatchState>(
      'izbor preživljava osvežavanje ako je zahtev i dalje na stranici',
      build: () => blocWith(repo([pending])),
      seed: () => loaded([pending]),
      act: (bloc) async {
        bloc.add(DispatchRequestSelected(pending.id));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const DispatchRequested());
      },
      skip: 1,
      expect: () => [
        const DispatchLoading(),
        loaded([pending], selectedId: pending.id),
      ],
    );

    blocTest<DispatchBloc, DispatchState>(
      'izbor nestaje ako zahteva posle filtera više nema',
      build: () => blocWith(repo([pending, taken])),
      seed: () => loaded([pending, taken]),
      act: (bloc) async {
        bloc.add(DispatchRequestSelected(taken.id));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const DispatchFilterChanged(RequestStatusFilter.submitted));
      },
      skip: 2,
      expect: () => [
        loaded([pending], all: [pending, taken], filter: RequestStatusFilter.submitted),
      ],
    );
  });

  group('dodela perača', () {
    blocTest<DispatchBloc, DispatchState>(
      'slobodan perač: zahtev zauzet, pa osveženi podaci i poruka',
      build: () => blocWith(repo([pending])),
      seed: () => loaded([pending]),
      act: (bloc) => bloc.add(DispatchAcceptRequested(pending.id, washer)),
      expect: () {
        final assigned = pending.copyWith(
          status: Accepted(washerId: washer, acceptedBy: dispatcher.id, at: now),
        );
        return [
          loaded([pending], busyId: pending.id),
          loaded([assigned], notice: RequestAssigned(assigned)),
        ];
      },
    );

    for (final (label, busy) in [('prihvaćen', taken), ('u toku', running)]) {
      blocTest<DispatchBloc, DispatchState>(
        'perač sa poslom koji je $label → WasherBusy, razlog i osveženi perači',
        build: () => blocWith(repo([pending, busy])),
        seed: () => loaded([pending, busy]),
        act: (bloc) => bloc.add(DispatchAcceptRequested(pending.id, washer)),
        expect: () => [
          loaded([pending, busy], busyId: pending.id),
          loaded([pending, busy], notice: const DispatchActionRejected(WasherBusy(washerId: WasherId('w-1')))),
        ],
      );
    }

    blocTest<DispatchBloc, DispatchState>(
      'perača je u međuvremenu zauzeo drugi dispečer: razlog ostaje, perači su osveženi',
      build: () {
        final repository = repo([pending, request('wr-9', hour: 3)]);
        repository.replace(
          request(
            'wr-9',
            hour: 3,
            status: Accepted(washerId: otherWasher, acceptedBy: const UserId('u-x'), at: now),
          ),
        );
        return blocWith(repository);
      },
      seed: () => loaded([pending, request('wr-9', hour: 3)]),
      act: (bloc) => bloc.add(DispatchAcceptRequested(pending.id, otherWasher)),
      skip: 1,
      verify: (bloc) {
        final state = bloc.state as DispatchLoaded;
        expect(state.notice, const DispatchActionRejected(WasherBusy(washerId: otherWasher)));
        expect(state.isWasherBusy(otherWasher), isTrue);
        expect(state.busyId, isNull);
      },
    );

    blocTest<DispatchBloc, DispatchState>(
      'već prihvaćen zahtev se ne dodeljuje ponovo → InvalidTransition',
      build: () => blocWith(repo([taken])),
      seed: () => loaded([taken]),
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
      build: () => blocWith(repo([pending])),
      seed: () => loaded([pending]),
      act: (bloc) => bloc
        ..add(DispatchAcceptRequested(pending.id, washer))
        ..add(DispatchAcceptRequested(pending.id, otherWasher)),
      expect: () {
        final assigned = pending.copyWith(
          status: Accepted(washerId: washer, acceptedBy: dispatcher.id, at: now),
        );
        return [
          loaded([pending], busyId: pending.id),
          loaded([assigned], notice: RequestAssigned(assigned)),
        ];
      },
    );

    blocTest<DispatchBloc, DispatchState>(
      'prekid mreže pri radnji → DispatchActionFailed, bez ponavljanja i bez busy indikatora',
      build: () => blocWith(repo([pending])..failingRequests = 1),
      seed: () => loaded([pending]),
      act: (bloc) => bloc.add(DispatchAcceptRequested(pending.id, washer)),
      expect: () => [
        loaded([pending], busyId: pending.id),
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
      build: () => blocWith(repo([taken])),
      seed: () => loaded([taken]),
      act: (bloc) => bloc.add(DispatchReleaseRequested(taken.id)),
      skip: 1,
      expect: () {
        final released = taken.copyWith(status: const Submitted());
        return [
          loaded([released], notice: RequestReleased(released)),
        ];
      },
    );

    blocTest<DispatchBloc, DispatchState>(
      'dispečer otkazuje i zahtev u toku; razlog se čuva',
      build: () => blocWith(repo([running])),
      seed: () => loaded([running]),
      act: (bloc) => bloc.add(DispatchCancelRequested(running.id, reason: 'Otkazao dispečer.')),
      skip: 1,
      expect: () {
        final cancelled = running.copyWith(
          status: Cancelled(reason: 'Otkazao dispečer.', cancelledBy: dispatcher.id, at: now),
        );
        return [
          loaded([cancelled], notice: RequestCancelledByStaff(cancelled)),
        ];
      },
    );
  });

  blocTest<DispatchBloc, DispatchState>(
    'potvrđena poruka se briše iz stanja',
    build: () => blocWith(repo([pending])),
    seed: () => loaded([pending], notice: RequestAssigned(pending)),
    act: (bloc) => bloc.add(const DispatchNoticeAcknowledged()),
    expect: () => [
      loaded([pending]),
    ],
  );
}
