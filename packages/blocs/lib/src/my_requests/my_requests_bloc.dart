import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:domain/domain.dart' as domain;
import 'package:equatable/equatable.dart';
import 'package:use_cases/use_cases.dart';

part 'my_requests_event.dart';
part 'my_requests_state.dart';

/// Glavni tok klijenta i perača: stranica njihovih zahteva i otkazivanje.
final class MyRequestsBloc extends Bloc<MyRequestsEvent, MyRequestsState> {
  MyRequestsBloc({required this.getMyRequests, required this.cancelRequest, required this.clock, required this.user})
    : super(const MyRequestsLoading()) {
    on<MyRequestsRequested>((event, emit) async {
      emit(const MyRequestsLoading());
      await _reload(emit);
    });
    on<MyRequestsPageRequested>((event, emit) async {
      if (state case MyRequestsLoaded(isBusy: true)) return;
      _offset = event.offset < 0 ? 0 : event.offset;
      emit(const MyRequestsLoading());
      await _reload(emit);
    });
    on<RequestCancellationRequested>(_onCancellationRequested);
    on<MyRequestsNoticeAcknowledged>((event, emit) {
      switch (state) {
        case final MyRequestsLoaded loaded when loaded.notice != null:
          emit(loaded.withNotice(null));
        case MyRequestsEmpty(notice: _?):
          emit(const MyRequestsEmpty());
        default:
          break;
      }
    });
  }

  final GetMyRequests getMyRequests;
  final CancelRequest cancelRequest;
  final Clock clock;
  final User user;
  int _offset = 0;

  Future<void> _onCancellationRequested(RequestCancellationRequested event, Emitter<MyRequestsState> emit) async {
    final current = state;
    if (current is! MyRequestsLoaded || current.isBusy) return;
    emit(current.withCancelling(event.id));
    final Result<WashRequest> result;
    try {
      result = await cancelRequest(id: event.id, reason: event.reason);
    } on Exception catch (cause) {
      emit(current.withNotice(CancellationFailed(cause)));
      return;
    }
    await _reload(
      emit,
      previous: current,
      notice: switch (result) {
        Success(:final value) => RequestCancelled(value),
        Failure(:final error) => CancellationRejected(error),
      },
    );
  }

  Future<void> _reload(Emitter<MyRequestsState> emit, {MyRequestsNotice? notice, MyRequestsLoaded? previous}) async {
    try {
      var page = await getMyRequests(offset: _offset);
      if (page.isPastEnd) {
        _offset = page.lastOffset;
        page = await getMyRequests(offset: _offset);
      }
      if (page.isEmpty) {
        emit(MyRequestsEmpty(notice: notice));
        return;
      }
      final now = clock.now();
      final active = page.items.where((r) => r.isActive);
      emit(
        MyRequestsLoaded(
          page: page,
          cancellable: {
            for (final r in active)
              if (domain.cancelRequest(r, by: user, now: now).isSuccess) r.id,
          },
          washerLate: {
            for (final r in active)
              if (isWasherLate(r, now: now)) r.id,
          },
          notice: notice,
        ),
      );
    } on Exception catch (cause) {
      if (previous != null && notice != null) {
        emit(previous.withNotice(notice));
      } else {
        emit(MyRequestsFailure(cause));
      }
    }
  }
}
