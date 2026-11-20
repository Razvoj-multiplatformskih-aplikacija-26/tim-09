import 'dart:async';

import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:use_cases/use_cases.dart';

final now = DateTime.utc(2026, 11, 20, 9);

WashRequest request(String id, WashStatus status) => WashRequest(
  id: WashRequestId(id),
  clientId: const UserId('u-client'),
  vehicle: const Vehicle(type: VehicleType.sedan, plate: LicensePlate.existing('BG 123-AB')),
  tier: ServiceTier.economy,
  address: const Address.existing('Knez Mihailova 6'),
  slot: WashSlot.existing(now.add(const Duration(days: 1)), const Duration(minutes: 45)),
  status: status,
  createdAt: now,
);

final submitted = request('wr-sub', const Submitted());
final accepted = request(
  'wr-acc',
  Accepted(washerId: const WasherId('w-1'), acceptedBy: const UserId('u-dispatcher'), at: now),
);
const washerList = [Washer(id: WasherId('w-1'), name: 'Nikola Petrović', hasActiveJob: true)];

final class Pending<T> {
  Pending(this.query) : completer = Completer<T>();

  final RequestQuery? query;
  final Completer<T> completer;
}

final class ControlledBoard implements WashRequestRepository, WasherRepository {
  final lists = <Pending<RequestPage>>[];
  final washerCalls = <Pending<List<Washer>>>[];
  final assigns = <Pending<Result<WashRequest>>>[];
  bool autoWashers = true;

  @override
  Future<RequestPage> list(RequestQuery query) {
    final call = Pending<RequestPage>(query);
    lists.add(call);
    return call.completer.future;
  }

  @override
  Future<List<Washer>> washers() {
    if (autoWashers) return Future.value(washerList);
    final call = Pending<List<Washer>>(null);
    washerCalls.add(call);
    return call.completer.future;
  }

  @override
  Future<Result<WashRequest>> assign({required WashRequestId id, required WasherId washerId}) {
    final call = Pending<Result<WashRequest>>(null);
    assigns.add(call);
    return call.completer.future;
  }

  @override
  Future<WashRequest?> find(WashRequestId id) => throw UnimplementedError();

  @override
  Future<Result<WashRequest>> create(WashRequestDraft draft) => throw UnimplementedError();

  @override
  Future<Result<WashRequest>> cancel({required WashRequestId id, required String reason}) => throw UnimplementedError();

  @override
  Future<Result<WashRequest>> release({required WashRequestId id}) => throw UnimplementedError();
}

RequestPage pageOf(List<WashRequest> items, {int offset = 0, int? total}) =>
    RequestPage(items: items, total: total ?? items.length, limit: 50, offset: offset);

DispatchBloc blocOf(ControlledBoard board) => DispatchBloc(
  getAllRequests: GetAllRequests(requests: board),
  getWashers: GetWashers(washers: board),
  acceptRequest: AcceptRequest(requests: board),
  releaseRequest: ReleaseRequest(requests: board),
  cancelRequest: CancelRequest(requests: board),
);

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late ControlledBoard board;
  late DispatchBloc bloc;

  setUp(() {
    board = ControlledBoard();
    bloc = blocOf(board);
  });

  tearDown(() => bloc.close());

  test('stari odgovor filtera „Prihvaćen“ ne prepisuje noviji „Prijavljen“', () async {
    bloc.add(const DispatchFilterChanged(RequestStatusFilter.accepted));
    await flush();
    bloc.add(const DispatchFilterChanged(RequestStatusFilter.submitted));
    await flush();
    expect(board.lists.map((c) => c.query?.status), [RequestStatusFilter.accepted, RequestStatusFilter.submitted]);

    board.lists[1].completer.complete(pageOf([submitted]));
    await flush();
    expect((bloc.state as DispatchLoaded).requests, [submitted]);

    board.lists[0].completer.complete(pageOf([accepted]));
    await flush();
    final state = bloc.state as DispatchLoaded;
    expect(state.filter, RequestStatusFilter.submitted);
    expect(state.requests, [submitted]);
  });

  test('zakasnela greška starog upita ne zamenjuje noviju listu', () async {
    bloc.add(const DispatchFilterChanged(RequestStatusFilter.accepted));
    await flush();
    bloc.add(const DispatchFilterChanged(RequestStatusFilter.submitted));
    await flush();
    board.lists[1].completer.complete(pageOf([submitted]));
    await flush();
    board.lists[0].completer.completeError(const NetworkException('timeout', timedOut: true));
    await flush();
    expect(bloc.state, isA<DispatchLoaded>().having((s) => s.requests, 'requests', [submitted]));
  });

  test('stara stranica van opsega ne upisuje svoj offset u noviji filter', () async {
    bloc.add(const DispatchPageRequested(100));
    await flush();
    bloc.add(const DispatchFilterChanged(RequestStatusFilter.submitted));
    await flush();
    board.lists[1].completer.complete(pageOf([submitted]));
    await flush();
    board.lists[0].completer.complete(pageOf(const [], offset: 100, total: 60));
    await flush();
    expect(board.lists, hasLength(2));
    final state = bloc.state as DispatchLoaded;
    expect((state.filter, state.page.offset, state.requests.single), (RequestStatusFilter.submitted, 0, submitted));

    bloc.add(const DispatchRequested());
    await flush();
    expect(
      board.lists.last.query,
      const RequestQuery(scope: RequestScope.all, limit: 50, status: RequestStatusFilter.submitted),
    );
  });

  test('stari korak koji čeka perače ne emituje zastarelo stanje', () async {
    board.autoWashers = false;
    bloc.add(const DispatchFilterChanged(RequestStatusFilter.accepted));
    await flush();
    board.lists[0].completer.complete(pageOf([accepted]));
    await flush();
    bloc.add(const DispatchFilterChanged(RequestStatusFilter.submitted));
    await flush();
    board.lists[1].completer.complete(pageOf([submitted]));
    await flush();
    board.washerCalls[1].completer.complete(washerList);
    await flush();
    board.washerCalls[0].completer.complete(washerList);
    await flush();
    final state = bloc.state as DispatchLoaded;
    expect((state.filter, state.requests.single), (RequestStatusFilter.submitted, submitted));
  });

  test('stariji upit koji stigne posle početka radnje ne uklanja busy i ne dopušta drugi upis', () async {
    bloc.add(const DispatchFilterChanged(RequestStatusFilter.accepted));
    await flush();
    bloc.add(const DispatchFilterChanged(RequestStatusFilter.submitted));
    await flush();
    board.lists[1].completer.complete(pageOf([submitted]));
    await flush();

    bloc.add(DispatchAcceptRequested(submitted.id, const WasherId('w-1')));
    await flush();
    expect(board.assigns, hasLength(1));

    board.lists[0].completer.complete(pageOf([accepted]));
    await flush();
    final during = bloc.state as DispatchLoaded;
    expect(
      (during.busyId, during.filter, during.requests.single),
      (submitted.id, RequestStatusFilter.submitted, submitted),
    );

    bloc.add(DispatchAcceptRequested(submitted.id, const WasherId('w-1')));
    await flush();
    expect(board.assigns, hasLength(1));

    board.assigns[0].completer.complete(Success(accepted));
    await flush();
    board.lists[2].completer.complete(pageOf(const []));
    await flush();
    expect(
      bloc.state,
      isA<DispatchEmpty>()
          .having((s) => s.busyId, 'busyId', isNull)
          .having((s) => s.notice, 'notice', RequestAssigned(accepted)),
    );
  });

  test('poslednji važeći upit koji padne prikazuje grešku i retry', () async {
    bloc.add(const DispatchFilterChanged(RequestStatusFilter.cancelled));
    await flush();
    board.lists[0].completer.completeError(const NetworkException('down'));
    await flush();
    expect(bloc.state, isA<DispatchFailure>().having((s) => s.filter, 'filter', RequestStatusFilter.cancelled));
  });
}
