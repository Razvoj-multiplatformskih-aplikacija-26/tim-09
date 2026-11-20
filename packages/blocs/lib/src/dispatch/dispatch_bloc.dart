import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';
import 'package:use_cases/use_cases.dart';

part 'dispatch_event.dart';
part 'dispatch_state.dart';

/// Dispečerska tabla: stranica zahteva, perači, izbor jednog zahteva i radnje osoblja nad njim.
final class DispatchBloc extends Bloc<DispatchEvent, DispatchState> {
  DispatchBloc({
    required this.getAllRequests,
    required this.getWashers,
    required this.acceptRequest,
    required this.releaseRequest,
    required this.cancelRequest,
  }) : super(const DispatchLoading()) {
    on<DispatchRequested>(_onRequested);
    on<DispatchPageRequested>(_onPageRequested);
    on<DispatchFilterChanged>(_onFilterChanged);
    on<DispatchRequestSelected>(_onSelected);
    on<DispatchAcceptRequested>(_onAcceptRequested);
    on<DispatchReleaseRequested>(_onReleaseRequested);
    on<DispatchCancelRequested>(_onCancelRequested);
    on<DispatchNoticeAcknowledged>(_onNoticeAcknowledged);
  }

  final GetAllRequests getAllRequests;
  final GetWashers getWashers;
  final AcceptRequest acceptRequest;
  final ReleaseRequest releaseRequest;
  final CancelRequest cancelRequest;

  int _offset = 0;
  RequestStatusFilter? _filter;
  WashRequestId? _selectedId;
  int _generation = 0;

  bool get _acting => state is DispatchReady && (state as DispatchReady).busyId != null;

  Future<void> _onRequested(DispatchRequested event, Emitter<DispatchState> emit) async {
    if (_acting) return;
    emit(DispatchLoading(filter: _filter));
    await _reload(emit);
  }

  Future<void> _onPageRequested(DispatchPageRequested event, Emitter<DispatchState> emit) async {
    if (_acting) return;
    _offset = event.offset < 0 ? 0 : event.offset;
    emit(DispatchLoading(filter: _filter));
    await _reload(emit);
  }

  Future<void> _onFilterChanged(DispatchFilterChanged event, Emitter<DispatchState> emit) async {
    if (_acting) return;
    _filter = event.filter;
    _offset = 0;
    emit(DispatchLoading(filter: _filter));
    await _reload(emit);
  }

  void _onSelected(DispatchRequestSelected event, Emitter<DispatchState> emit) {
    final current = state;
    if (current is DispatchLoaded) {
      _selectedId = event.id;
      emit(current.copyWith(selectedId: event.id, clearSelected: event.id == null));
    }
  }

  void _onNoticeAcknowledged(DispatchNoticeAcknowledged event, Emitter<DispatchState> emit) {
    if (state case final DispatchReady ready when ready.notice != null) emit(ready.withAction(clearNotice: true));
  }

  Future<void> _onAcceptRequested(DispatchAcceptRequested event, Emitter<DispatchState> emit) =>
      _act(emit, event.id, () => acceptRequest(id: event.id, washer: event.washerId), RequestAssigned.new);

  Future<void> _onReleaseRequested(DispatchReleaseRequested event, Emitter<DispatchState> emit) =>
      _act(emit, event.id, () => releaseRequest(id: event.id), RequestReleased.new);

  Future<void> _onCancelRequested(DispatchCancelRequested event, Emitter<DispatchState> emit) =>
      _act(emit, event.id, () => cancelRequest(id: event.id, reason: event.reason), RequestCancelledByStaff.new);

  /// Izbor preživljava osvežavanje samo ako je zahtev i dalje na stranici.
  Future<void> _reload(Emitter<DispatchState> emit, {DispatchNotice? notice, DispatchReady? previous}) async {
    final generation = ++_generation;
    final filter = _filter;
    var offset = _offset;
    bool stale() => generation != _generation || emit.isDone;
    try {
      var page = await getAllRequests(offset: offset, status: filter);
      if (stale()) return;
      if (page.isPastEnd) {
        offset = page.lastOffset;
        page = await getAllRequests(offset: offset, status: filter);
        if (stale()) return;
      }
      final washers = await getWashers();
      if (stale()) return;
      _offset = offset;
      if (!page.items.any((r) => r.id == _selectedId)) _selectedId = null;
      if (page.isEmpty) {
        emit(DispatchEmpty(washers: washers, filter: filter, notice: notice));
        return;
      }
      emit(DispatchLoaded(page: page, washers: washers, filter: filter, selectedId: _selectedId, notice: notice));
    } on Exception catch (cause) {
      if (stale()) return;
      if (previous != null && notice != null) {
        emit(previous.withAction(clearBusy: true, notice: notice));
      } else {
        emit(DispatchFailure(cause, filter: filter));
      }
    }
  }

  /// Zajednički tok radnje: zauzmi zahtev, pozovi use case, pa osveži podatke i javi ishod.
  /// Dok jedna radnja traje, nova se ignoriše.
  Future<void> _act(
    Emitter<DispatchState> emit,
    WashRequestId id,
    Future<Result<WashRequest>> Function() action,
    DispatchNotice Function(WashRequest) onSuccess,
  ) async {
    final current = state;
    if (current is! DispatchReady || current.busyId != null) return;
    _generation++;
    emit(current.withAction(busyId: id));
    final Result<WashRequest> result;
    try {
      result = await action();
    } on Exception catch (cause) {
      emit(current.withAction(clearBusy: true, notice: DispatchActionFailed(cause)));
      return;
    }
    await _reload(
      emit,
      previous: current,
      notice: switch (result) {
        Success(:final value) => onSuccess(value),
        Failure(:final error) => DispatchActionRejected(error),
      },
    );
  }
}
