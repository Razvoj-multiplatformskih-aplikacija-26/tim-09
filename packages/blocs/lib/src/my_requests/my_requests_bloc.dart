import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:domain/domain.dart' as domain;
import 'package:equatable/equatable.dart';
import 'package:use_cases/use_cases.dart';

part 'my_requests_event.dart';
part 'my_requests_state.dart';

/// Glavni tok klijenta: učitavanje njegovih zahteva i otkazivanje.
final class MyRequestsBloc extends Bloc<MyRequestsEvent, MyRequestsState> {
  MyRequestsBloc({required this.getMyRequests, required this.cancelRequest, required this.clock, required this.client})
    : super(const MyRequestsLoading()) {
    on<MyRequestsRequested>((event, emit) async {
      emit(const MyRequestsLoading());
      await _reload(emit);
    });
    on<RequestCancellationRequested>(_onCancellationRequested);
    on<MyRequestsNoticeAcknowledged>((event, emit) {
      final current = state;
      if (current is MyRequestsLoaded && current.notice != null) emit(current.withNotice(null));
    });
  }

  final GetMyRequests getMyRequests;
  final CancelRequest cancelRequest;
  final Clock clock;
  final User client;

  Future<void> _onCancellationRequested(RequestCancellationRequested event, Emitter<MyRequestsState> emit) async {
    final current = state;
    if (current is! MyRequestsLoaded) return;
    emit(current.withCancelling(event.id));
    final Result<WashRequest> result;
    try {
      result = await cancelRequest(id: event.id, by: client, reason: event.reason);
    } on Exception catch (cause) {
      emit(current.withNotice(CancellationFailed(cause)));
      return;
    }
    switch (result) {
      case Success(:final value):
        await _reload(emit, notice: RequestCancelled(value));
      case Failure(:final error):
        emit(current.withNotice(CancellationRejected(error)));
    }
  }

  Future<void> _reload(Emitter<MyRequestsState> emit, {MyRequestsNotice? notice}) async {
    try {
      final requests = await getMyRequests(client);
      if (requests.isEmpty) {
        emit(const MyRequestsEmpty());
        return;
      }
      final now = clock.now();
      final active = requests.where((r) => r.isActive).toList();
      final past = requests.where((r) => !r.isActive).toList().reversed.toList();
      // Pravilo otkazivanja živi u domenu; ovde ga samo pitamo za svaki zahtev.
      final cancellable = {
        for (final r in active)
          if (domain.cancelRequest(r, by: client, now: now).isSuccess) r.id,
      };
      final washerLate = {
        for (final r in active)
          if (isWasherLate(r, now: now)) r.id,
      };
      emit(
        MyRequestsLoaded(active: active, past: past, cancellable: cancellable, washerLate: washerLate, notice: notice),
      );
    } on Exception catch (cause) {
      emit(MyRequestsFailure(cause));
    }
  }
}
