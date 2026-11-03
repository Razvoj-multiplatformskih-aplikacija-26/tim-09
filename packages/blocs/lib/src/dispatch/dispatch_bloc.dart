import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';
import 'package:use_cases/use_cases.dart';

part 'dispatch_event.dart';
part 'dispatch_state.dart';

final class DispatchBloc extends Bloc<DispatchEvent, DispatchState> {
  DispatchBloc({
    required this.getAllRequests,
    required this.acceptRequest,
    required this.releaseRequest,
    required this.cancelRequest,
    required this.clock,
    required this.dispatcher,
  }) : super(const DispatchLoading()) {
    on<DispatchRequested>(_onRequested);
    on<DispatchRequestSelected>(_onSelected);
    on<AcceptRequested>(_onAcceptRequested);
    on<ReleaseRequested>(_onReleaseRequested);
    on<DispatchCancelRequested>(_onCancelRequested);
    on<DispatchNoticeAcknowledged>(_onNoticeAcknowledged);
  }

  final GetAllRequests getAllRequests;
  final AcceptRequest acceptRequest;
  final ReleaseRequest releaseRequest;
  final CancelRequest cancelRequest;
  final Clock clock;
  final User dispatcher;

  Future<void> _onRequested(DispatchRequested event, Emitter<DispatchState> emit) async {
    emit(const DispatchLoading());
    await _reload(emit);
  }

  void _onSelected(DispatchRequestSelected event, Emitter<DispatchState> emit) {
    final current = state;
    if (current is DispatchLoaded) {
      emit(current.copyWith(selectedId: event.id, clearSelected: event.id == null));
    }
  }

  void _onNoticeAcknowledged(DispatchNoticeAcknowledged event, Emitter<DispatchState> emit) {
    final current = state;
    if (current is DispatchLoaded && current.notice != null) {
      emit(current.copyWith(clearNotice: true));
    }
  }

  Future<void> _onAcceptRequested(AcceptRequested event, Emitter<DispatchState> emit) => _act(
    emit,
    event.id,
    () => acceptRequest(id: event.id, washer: event.washerId, by: dispatcher, now: clock.now()),
    RequestAssigned.new,
  );

  Future<void> _onReleaseRequested(ReleaseRequested event, Emitter<DispatchState> emit) =>
      _act(emit, event.id, () => releaseRequest(id: event.id, by: dispatcher), RequestReleased.new);

  Future<void> _onCancelRequested(DispatchCancelRequested event, Emitter<DispatchState> emit) =>
      _act(emit, event.id, () => cancelRequest(id: event.id, by: dispatcher), RequestCancelledByStaff.new);

  Future<void> _reload(Emitter<DispatchState> emit, {DispatchNotice? notice}) async {
    try {
      final requests = await getAllRequests();
      if (requests.isEmpty) {
        emit(const DispatchEmpty());
        return;
      }
      final current = state;
      final selectedId = current is DispatchLoaded ? current.selectedId : null;
      final validSelectedId = requests.any((r) => r.id == selectedId) ? selectedId : null;

      emit(DispatchLoaded(requests: requests, selectedId: validSelectedId, notice: notice));
    } on Exception catch (cause) {
      emit(DispatchFailure(cause));
    }
  }

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
    switch (result) {
      case Success(:final value):
        await _reload(emit, notice: onSuccess(value));
      case Failure(:final error):
        emit(current.copyWith(clearBusy: true, notice: DispatchActionRejected(error)));
    }
  }
}
