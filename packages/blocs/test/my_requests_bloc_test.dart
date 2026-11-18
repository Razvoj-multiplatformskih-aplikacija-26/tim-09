import 'package:bloc_test/bloc_test.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:use_cases/testing.dart';
import 'package:use_cases/use_cases.dart';

import 'fake_wash_requests.dart';

final now = businessDate(2026, 10, 26, 9);
const client = User(id: UserId('u-client'), username: 'marko', role: Role.client);
const washerUser = User(id: UserId('u-washer-1'), username: 'nikola', role: Role.washer, washerId: WasherId('w-1'));

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

MyRequestsBloc blocWith(InMemoryWashRequests repository, {User user = client}) => MyRequestsBloc(
  getMyRequests: GetMyRequests(requests: repository),
  cancelRequest: CancelRequest(requests: repository),
  clock: FixedClock(now),
  user: user,
);

void main() {
  final upcoming = request('wr-1', start: now.add(const Duration(days: 1)));
  final soon = request(
    'wr-2',
    start: now.add(const Duration(minutes: 30)),
    status: Accepted(washerId: const WasherId('w-1'), acceptedBy: const UserId('u-d'), at: now),
  );
  final done = request(
    'wr-3',
    start: now.subtract(const Duration(days: 1)),
    status: Completed(finishedAt: now),
  );

  blocTest<MyRequestsBloc, MyRequestsState>(
    'učitavanje stranice; Bloc iz domena zna šta sme da se otkaže',
    build: () => blocWith(fakeRequests(client, now, [upcoming, soon, done])),
    act: (bloc) => bloc.add(const MyRequestsRequested()),
    expect: () => [
      const MyRequestsLoading(),
      isA<MyRequestsLoaded>()
          .having((s) => s.active, 'active', [soon, upcoming])
          .having((s) => s.past, 'past', [done])
          .having((s) => s.cancellable, 'cancellable', {upcoming.id})
          .having((s) => s.page.total, 'total', 3),
    ],
  );

  blocTest<MyRequestsBloc, MyRequestsState>(
    'bez zahteva → prazno',
    build: () => blocWith(fakeRequests(client, now)),
    act: (bloc) => bloc.add(const MyRequestsRequested()),
    expect: () => [const MyRequestsLoading(), const MyRequestsEmpty()],
  );

  blocTest<MyRequestsBloc, MyRequestsState>(
    'greška mreže → Failure, „Pokušaj ponovo“ → podaci',
    build: () => blocWith(fakeRequests(client, now, [upcoming])..failingRequests = 1),
    act: (bloc) async {
      bloc.add(const MyRequestsRequested());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const MyRequestsRequested());
    },
    expect: () => [
      const MyRequestsLoading(),
      isA<MyRequestsFailure>().having((s) => s.cause, 'cause', isA<NetworkException>()),
      const MyRequestsLoading(),
      MyRequestsLoaded(page: pageOf([upcoming]), cancellable: {upcoming.id}),
    ],
  );

  group('stranice', () {
    final many = [
      for (var i = 0; i < 25; i++)
        request('r${i.toString().padLeft(2, '0')}', start: now.add(Duration(days: 1, minutes: 30 * i))),
    ];

    blocTest<MyRequestsBloc, MyRequestsState>(
      'sledeća stranica nosi total, limit i offset sa servera',
      build: () => blocWith(fakeRequests(client, now, many)),
      act: (bloc) => bloc.add(const MyRequestsPageRequested(20)),
      expect: () => [
        const MyRequestsLoading(),
        isA<MyRequestsLoaded>()
            .having((s) => s.page.items.length, 'items', 5)
            .having((s) => (s.page.total, s.page.offset, s.page.limit), 'page', (25, 20, 20))
            .having((s) => s.page.hasNext, 'hasNext', isFalse),
      ],
    );

    blocTest<MyRequestsBloc, MyRequestsState>(
      'offset van opsega učitava poslednju važeću stranicu',
      build: () => blocWith(fakeRequests(client, now, many)),
      act: (bloc) => bloc.add(const MyRequestsPageRequested(60)),
      expect: () => [const MyRequestsLoading(), isA<MyRequestsLoaded>().having((s) => s.page.offset, 'offset', 20)],
    );
  });

  blocTest<MyRequestsBloc, MyRequestsState>(
    'otkazivanje: dugme zauzeto, pa osvežena lista sa otkazanim zahtevom i porukom',
    build: () => blocWith(fakeRequests(client, now, [upcoming])),
    seed: () => MyRequestsLoaded(page: pageOf([upcoming]), cancellable: {upcoming.id}),
    act: (bloc) => bloc.add(RequestCancellationRequested(upcoming.id, reason: 'Otkazao klijent.')),
    expect: () {
      final cancelled = upcoming.copyWith(
        status: Cancelled(reason: 'Otkazao klijent.', cancelledBy: client.id, at: now),
      );
      return [
        MyRequestsLoaded(page: pageOf([upcoming]), cancellable: {upcoming.id}, cancellingId: upcoming.id),
        MyRequestsLoaded(page: pageOf([cancelled]), cancellable: const {}, notice: RequestCancelled(cancelled)),
      ];
    },
  );

  blocTest<MyRequestsBloc, MyRequestsState>(
    'prekasno otkazivanje → razlog ostaje uz osvežene podatke',
    build: () => blocWith(fakeRequests(client, now, [soon])),
    seed: () => MyRequestsLoaded(page: pageOf([soon]), cancellable: const {}),
    act: (bloc) => bloc.add(RequestCancellationRequested(soon.id)),
    skip: 1,
    expect: () => [
      MyRequestsLoaded(
        page: pageOf([soon]),
        cancellable: const {},
        notice: const CancellationRejected(CancellationTooLate()),
      ),
    ],
  );

  blocTest<MyRequestsBloc, MyRequestsState>(
    'odbijanje pa prazan reload → poruka ostaje u praznom stanju',
    build: () => blocWith(fakeRequests(client, now, [soon])..emptyResponses = 1),
    seed: () => MyRequestsLoaded(page: pageOf([soon]), cancellable: const {}),
    act: (bloc) => bloc.add(RequestCancellationRequested(soon.id)),
    skip: 1,
    expect: () => [const MyRequestsEmpty(notice: CancellationRejected(CancellationTooLate()))],
  );

  blocTest<MyRequestsBloc, MyRequestsState>(
    'odbijanje pa neuspešan reload → stari podaci i prvobitni razlog, bez zauzetog dugmeta',
    build: () {
      final repository = fakeRequests(client, now, [soon]);
      return MyRequestsBloc(
        getMyRequests: GetMyRequests(requests: _FailingList(repository)),
        cancelRequest: CancelRequest(requests: repository),
        clock: FixedClock(now),
        user: client,
      );
    },
    seed: () => MyRequestsLoaded(page: pageOf([soon]), cancellable: const {}),
    act: (bloc) => bloc.add(RequestCancellationRequested(soon.id)),
    skip: 1,
    expect: () => [
      MyRequestsLoaded(
        page: pageOf([soon]),
        cancellable: const {},
        notice: const CancellationRejected(CancellationTooLate()),
      ),
    ],
  );

  blocTest<MyRequestsBloc, MyRequestsState>(
    'prekid mreže pri otkazivanju ne ponavlja upis i oslobađa dugme',
    build: () => blocWith(fakeRequests(client, now, [upcoming])..failingRequests = 1),
    seed: () => MyRequestsLoaded(page: pageOf([upcoming]), cancellable: {upcoming.id}),
    act: (bloc) => bloc.add(RequestCancellationRequested(upcoming.id)),
    skip: 1,
    expect: () => [
      isA<MyRequestsLoaded>()
          .having((s) => s.isBusy, 'busy', isFalse)
          .having((s) => s.notice, 'notice', isA<CancellationFailed>()),
    ],
  );

  blocTest<MyRequestsBloc, MyRequestsState>(
    'perač vidi svoje aktivne poslove bez klijentskog otkazivanja',
    build: () => blocWith(fakeRequests(washerUser, now, [upcoming, soon]), user: washerUser),
    act: (bloc) => bloc.add(const MyRequestsRequested()),
    expect: () => [
      const MyRequestsLoading(),
      MyRequestsLoaded(page: pageOf([soon]), cancellable: const {}, washerLate: const {}),
    ],
  );
}

final class _FailingList implements WashRequestRepository {
  _FailingList(this.inner);

  final WashRequestRepository inner;

  @override
  Future<RequestPage> list(RequestQuery query) async => throw const NetworkException('down');

  @override
  Future<WashRequest?> find(WashRequestId id) => inner.find(id);

  @override
  Future<Result<WashRequest>> create(WashRequestDraft draft) => inner.create(draft);

  @override
  Future<Result<WashRequest>> cancel({required WashRequestId id, required String reason}) =>
      inner.cancel(id: id, reason: reason);

  @override
  Future<Result<WashRequest>> assign({required WashRequestId id, required WasherId washerId}) =>
      inner.assign(id: id, washerId: washerId);

  @override
  Future<Result<WashRequest>> release({required WashRequestId id}) => inner.release(id: id);
}
