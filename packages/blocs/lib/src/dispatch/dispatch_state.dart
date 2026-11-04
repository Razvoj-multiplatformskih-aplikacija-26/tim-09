part of 'dispatch_bloc.dart';

sealed class DispatchState extends Equatable {
  const DispatchState();

  @override
  List<Object?> get props => const [];

  @override
  String toString() => '$runtimeType';
}

final class DispatchLoading extends DispatchState {
  const DispatchLoading();
}

final class DispatchFailure extends DispatchState {
  const DispatchFailure(this.cause);

  final Object cause;

  @override
  List<Object?> get props => [cause];

  @override
  String toString() => 'DispatchFailure($cause)';
}

final class DispatchEmpty extends DispatchState {
  const DispatchEmpty();
}

final class DispatchLoaded extends DispatchState {
  const DispatchLoaded({required this.requests, this.selectedId, this.busyId, this.notice});

  final List<WashRequest> requests;
  final WashRequestId? selectedId;
  final WashRequestId? busyId;
  final DispatchNotice? notice;

  WashRequest? get selected => find(selectedId);

  WashRequest? find(WashRequestId? id) => requests.where((r) => r.id == id).firstOrNull;

  bool isBusy(WashRequest request) => busyId == request.id;

  @override
  List<Object?> get props => [requests, selectedId, busyId, notice];

  @override
  String toString() => [
    'DispatchLoaded(${requests.length} requests',
    if (selectedId case final id?) ', selected ${id.value}',
    if (busyId case final id?) ', busy ${id.value}',
    if (notice case final notice?) ', ${notice.runtimeType}',
    ')',
  ].join();

  DispatchLoaded copyWith({
    List<WashRequest>? requests,
    WashRequestId? selectedId,
    bool clearSelected = false,
    WashRequestId? busyId,
    bool clearBusy = false,
    DispatchNotice? notice,
    bool clearNotice = false,
  }) {
    return DispatchLoaded(
      requests: requests ?? this.requests,
      selectedId: clearSelected ? null : (selectedId ?? this.selectedId),
      busyId: clearBusy ? null : (busyId ?? this.busyId),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}

/// Jednokratna poruka posle radnje; ekran je prikaže i pošalje [DispatchNoticeAcknowledged].
sealed class DispatchNotice extends Equatable {
  const DispatchNotice();

  @override
  List<Object?> get props => const [];
}

final class RequestAssigned extends DispatchNotice {
  const RequestAssigned(this.request);

  final WashRequest request;

  @override
  List<Object?> get props => [request];
}

final class RequestReleased extends DispatchNotice {
  const RequestReleased(this.request);

  final WashRequest request;

  @override
  List<Object?> get props => [request];
}

final class RequestCancelledByStaff extends DispatchNotice {
  const RequestCancelledByStaff(this.request);

  final WashRequest request;

  @override
  List<Object?> get props => [request];
}

final class DispatchActionRejected extends DispatchNotice {
  const DispatchActionRejected(this.error);

  final DomainError error;

  @override
  List<Object?> get props => [error];
}

final class DispatchActionFailed extends DispatchNotice {
  const DispatchActionFailed(this.cause);

  final Object cause;

  @override
  List<Object?> get props => [cause];
}
