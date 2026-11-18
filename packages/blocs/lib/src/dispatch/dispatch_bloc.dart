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

  Future<void> _onRequested(DispatchRequested event, Emitter<DispatchState> emit) async {
    if (state case DispatchLoaded(busyId: _?)) return;
    emit(DispatchLoading(filter: _filter));
    await _reload(emit);
  }

  Future<void> _onPageRequested(DispatchPageRequested event, Emitter<DispatchState> emit) async {
    if (state case DispatchLoaded(busyId: _?)) return;
    _offset = event.offset < 0 ? 0 : event.offset;
    emit(DispatchLoading(filter: _filter));
    await _reload(emit);
  }

  Future<void> _onFilterChanged(DispatchFilterChanged event, Emitter<DispatchState> emit) async {
    if (state case DispatchLoaded(busyId: _?)) return;
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
    switch (state) {
      case final DispatchLoaded loaded when loaded.notice != null:
        emit(loaded.copyWith(clearNotice: true));
      case DispatchEmpty(:final filter, notice: _?):
        emit(DispatchEmpty(filter: filter));
      default:
        break;
    }
  }

  Future<void> _onAcceptRequested(DispatchAcceptRequested event, Emitter<DispatchState> emit) =>
      _act(emit, event.id, () => acceptRequest(id: event.id, washer: event.washerId), RequestAssigned.new);

  Future<void> _onReleaseRequested(DispatchReleaseRequested event, Emitter<DispatchState> emit) =>
      _act(emit, event.id, () => releaseRequest(id: event.id), RequestReleased.new);

  Future<void> _onCancelRequested(DispatchCancelRequested event, Emitter<DispatchState> emit) =>
      _act(emit, event.id, () => cancelRequest(id: event.id, reason: event.reason), RequestCancelledByStaff.new);

  /// Izbor preživljava osvežavanje samo ako je zahtev i dalje na stranici.
  Future<void> _reload(Emitter<DispatchState> emit, {DispatchNotice? notice, DispatchLoaded? previous}) async {
    try {
      var page = await getAllRequests(offset: _offset, status: _filter);
      if (page.isPastEnd) {
        _offset = page.lastOffset;
        page = await getAllRequests(offset: _offset, status: _filter);
      }
      final washers = await getWashers();
      if (page.isEmpty) {
        emit(DispatchEmpty(filter: _filter, notice: notice));
        return;
      }
      final stillThere = page.items.any((r) => r.id == _selectedId);
      if (!stillThere) _selectedId = null;
      emit(DispatchLoaded(page: page, washers: washers, filter: _filter, selectedId: _selectedId, notice: notice));
    } on Exception catch (cause) {
      if (previous != null && notice != null) {
        emit(previous.copyWith(clearBusy: true, notice: notice));
      } else {
        emit(DispatchFailure(cause, filter: _filter));
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
    if (current is! DispatchLoaded || current.busyId != null) return;
    emit(current.copyWith(busyId: id));
    final Result<WashRequest> result;
    try {
      result = await action();
    } on Exception catch (cause) {
      emit(current.copyWith(clearBusy: true, notice: DispatchActionFailed(cause)));
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
