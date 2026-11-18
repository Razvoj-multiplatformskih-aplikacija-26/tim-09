import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:domain/domain.dart' as domain;
import 'package:equatable/equatable.dart';
import 'package:use_cases/use_cases.dart';

import '../my_requests/my_requests_bloc.dart';

part 'request_detail_event.dart';
part 'request_detail_state.dart';

final class RequestDetailBloc extends Bloc<RequestDetailEvent, RequestDetailState> {
  RequestDetailBloc({
    required this.id,
    required this.getRequest,
    required this.clock,
    required this.user,
    this.cancelRequest,
  }) : super(const RequestDetailLoading()) {
    on<RequestDetailRequested>((event, emit) async {
      if (state case RequestDetailLoaded(cancelling: true)) return;
      if (!event.quiet || state is! RequestDetailLoaded) emit(const RequestDetailLoading());
      await _reload(emit);
    });
    on<RequestDetailCancelRequested>(_onCancelRequested);
    on<RequestDetailNoticeAcknowledged>((event, emit) {
      if (state case final RequestDetailLoaded loaded when loaded.notice != null) emit(loaded.withNotice(null));
    });
  }

  final WashRequestId id;
  final GetRequest getRequest;
  final CancelRequest? cancelRequest;
  final Clock clock;
  final User user;

  Future<void> _onCancelRequested(RequestDetailCancelRequested event, Emitter<RequestDetailState> emit) async {
    final current = state;
    final cancel = cancelRequest;
    if (current is! RequestDetailLoaded || current.cancelling || cancel == null) return;
    emit(current.withCancelling());
    final Result<WashRequest> result;
    try {
      result = await cancel(id: id, reason: event.reason);
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

  Future<void> _reload(
    Emitter<RequestDetailState> emit, {
    MyRequestsNotice? notice,
    RequestDetailLoaded? previous,
  }) async {
    try {
      final request = await getRequest(id);
      if (request == null) {
        emit(const RequestDetailUnavailable());
        return;
      }
      final now = clock.now();
      emit(
        RequestDetailLoaded(
          request,
          canCancel: cancelRequest != null && domain.cancelRequest(request, by: user, now: now).isSuccess,
          washerLate: isWasherLate(request, now: now),
          notice: notice,
        ),
      );
    } on Exception catch (cause) {
      if (previous != null && notice != null) {
        emit(previous.withNotice(notice));
      } else {
        emit(RequestDetailFailure(cause));
      }
    }
  }
}
