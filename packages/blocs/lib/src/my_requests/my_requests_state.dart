part of 'my_requests_bloc.dart';

sealed class MyRequestsState extends Equatable {
  const MyRequestsState();

  @override
  List<Object?> get props => const [];

  @override
  String toString() => '$runtimeType';
}

final class MyRequestsLoading extends MyRequestsState {
  const MyRequestsLoading();
}

final class MyRequestsFailure extends MyRequestsState {
  const MyRequestsFailure(this.cause);

  final Object cause;

  @override
  List<Object?> get props => [cause];

  @override
  String toString() => 'MyRequestsFailure($cause)';
}

final class MyRequestsEmpty extends MyRequestsState {
  const MyRequestsEmpty();
}

final class MyRequestsLoaded extends MyRequestsState {
  const MyRequestsLoaded({
    required this.active,
    required this.past,
    required this.cancellable,
    this.washerLate = const {},
    this.notice,
    this.cancellingId,
  });

  final List<WashRequest> active;
  final List<WashRequest> past;
  final Set<WashRequestId> cancellable;
  final Set<WashRequestId> washerLate;
  final MyRequestsNotice? notice;
  final WashRequestId? cancellingId;

  @override
  List<Object?> get props => [active, past, cancellable, washerLate, notice, cancellingId];

  @override
  String toString() => [
    'MyRequestsLoaded(${active.length} active, ${past.length} past',
    if (cancellingId case final id?) ', cancelling ${id.value}',
    if (notice case final notice?) ', ${notice.runtimeType}',
    ')',
  ].join();

  WashRequest? find(WashRequestId id) => active.followedBy(past).where((r) => r.id == id).firstOrNull;

  bool canCancel(WashRequest request) => cancellable.contains(request.id);

  bool isWasherLate(WashRequest request) => washerLate.contains(request.id);

  bool get isBusy => cancellingId != null;

  bool isCancelling(WashRequest request) => cancellingId == request.id;

  MyRequestsLoaded withNotice(MyRequestsNotice? notice) =>
      MyRequestsLoaded(active: active, past: past, cancellable: cancellable, washerLate: washerLate, notice: notice);

  MyRequestsLoaded withCancelling(WashRequestId id) =>
      MyRequestsLoaded(active: active, past: past, cancellable: cancellable, washerLate: washerLate, cancellingId: id);
}

/// Jednokratna poruka posle akcije; ekran je prikaže i pošalje [MyRequestsNoticeAcknowledged].
sealed class MyRequestsNotice extends Equatable {
  const MyRequestsNotice();

  @override
  List<Object?> get props => const [];
}

final class RequestCancelled extends MyRequestsNotice {
  const RequestCancelled(this.request);

  final WashRequest request;

  @override
  List<Object?> get props => [request];
}

final class CancellationRejected extends MyRequestsNotice {
  const CancellationRejected(this.error);

  final DomainError error;

  @override
  List<Object?> get props => [error];
}

final class CancellationFailed extends MyRequestsNotice {
  const CancellationFailed(this.cause);

  final Object cause;

  @override
  List<Object?> get props => [cause];
}
