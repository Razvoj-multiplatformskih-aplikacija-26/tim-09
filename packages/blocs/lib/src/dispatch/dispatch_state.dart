part of 'dispatch_bloc.dart';

sealed class DispatchState extends Equatable {
  const DispatchState();

  RequestStatusFilter? get filter => null;

  DispatchNotice? get notice => null;

  @override
  List<Object?> get props => const [];

  @override
  String toString() => '$runtimeType';
}

final class DispatchLoading extends DispatchState {
  const DispatchLoading({this.filter});

  @override
  final RequestStatusFilter? filter;

  @override
  List<Object?> get props => [filter];
}

final class DispatchFailure extends DispatchState {
  const DispatchFailure(this.cause, {this.filter});

  final Object cause;
  @override
  final RequestStatusFilter? filter;

  @override
  List<Object?> get props => [cause, filter];

  @override
  String toString() => 'DispatchFailure(${cause.runtimeType})';
}

final class DispatchEmpty extends DispatchState {
  const DispatchEmpty({this.filter, this.notice});

  @override
  final RequestStatusFilter? filter;
  @override
  final DispatchNotice? notice;

  @override
  List<Object?> get props => [filter, notice];
}

final class DispatchLoaded extends DispatchState {
  const DispatchLoaded({
    required this.page,
    required this.washers,
    this.filter,
    this.selectedId,
    this.busyId,
    this.notice,
  });

  final RequestPage page;
  final List<Washer> washers;
  @override
  final RequestStatusFilter? filter;
  final WashRequestId? selectedId;
  final WashRequestId? busyId;
  @override
  final DispatchNotice? notice;

  List<WashRequest> get requests => page.items;

  WashRequest? get selected => find(selectedId);

  WashRequest? find(WashRequestId? id) => requests.where((r) => r.id == id).firstOrNull;

  bool isBusy(WashRequest request) => busyId == request.id;

  /// Dostupnost perača računa server nad svim aktivnim poslovima, ne samo nad ovom stranicom.
  bool isWasherBusy(WasherId washer) => washers.where((w) => w.id == washer).firstOrNull?.hasActiveJob ?? false;

  String washerName(WasherId washer) => washers.where((w) => w.id == washer).firstOrNull?.name ?? washer.value;

  @override
  List<Object?> get props => [
    page,
    washers.map((w) => (w.id, w.name, w.hasActiveJob)).toList(),
    filter,
    selectedId,
    busyId,
    notice,
  ];

  @override
  String toString() => [
    'DispatchLoaded(${requests.length} of ${page.total} at ${page.offset}',
    if (filter case final filter?) ', ${filter.name}',
    if (selectedId case final id?) ', selected ${id.value}',
    if (busyId case final id?) ', busy ${id.value}',
    if (notice case final notice?) ', ${notice.runtimeType}',
    ')',
  ].join();

  DispatchLoaded copyWith({
    WashRequestId? selectedId,
    bool clearSelected = false,
    WashRequestId? busyId,
    bool clearBusy = false,
    DispatchNotice? notice,
    bool clearNotice = false,
  }) {
    return DispatchLoaded(
      page: page,
      washers: washers,
      filter: filter,
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
