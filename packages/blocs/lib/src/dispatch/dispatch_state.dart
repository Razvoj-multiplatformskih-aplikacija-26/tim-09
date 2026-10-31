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
}

final class DispatchEmpty extends DispatchState {
  const DispatchEmpty();
}

final class DispatchLoaded extends DispatchState {
  const DispatchLoaded({
    required this.requests,
    this.selectedId,
    this.busyId,
    this.notice,
  });

  final List<WashRequest> requests;
  final WashRequestId? selectedId;
  final WashRequestId? busyId;
  final DispatchNotice? notice;

  @override
  List<Object?> get props => [requests, selectedId, busyId, notice];

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

/// Jednokratne poruke nakon akcija osoblja (uspeh, odbijanje od strane domena, greška).
sealed class DispatchNotice extends Equatable {
  const DispatchNotice();

  @override
  List<Object?> get props => const [];
}

final class DispatchActionSuccess extends DispatchNotice {
  const DispatchActionSuccess(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
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