part of 'request_detail_bloc.dart';

sealed class RequestDetailState extends Equatable {
  const RequestDetailState();

  @override
  List<Object?> get props => const [];

  @override
  String toString() => '$runtimeType';
}

final class RequestDetailLoading extends RequestDetailState {
  const RequestDetailLoading();
}

final class RequestDetailUnavailable extends RequestDetailState {
  const RequestDetailUnavailable();
}

final class RequestDetailFailure extends RequestDetailState {
  const RequestDetailFailure(this.cause);

  final Object cause;

  @override
  List<Object?> get props => [cause];

  @override
  String toString() => 'RequestDetailFailure(${cause.runtimeType})';
}

final class RequestDetailLoaded extends RequestDetailState {
  const RequestDetailLoaded(
    this.request, {
    this.canCancel = false,
    this.washerLate = false,
    this.cancelling = false,
    this.notice,
  });

  final WashRequest request;
  final bool canCancel;
  final bool washerLate;
  final bool cancelling;
  final MyRequestsNotice? notice;

  @override
  List<Object?> get props => [request, canCancel, washerLate, cancelling, notice];

  @override
  String toString() => [
    'RequestDetailLoaded(${request.id.value}',
    if (cancelling) ', cancelling',
    if (notice case final notice?) ', ${notice.runtimeType}',
    ')',
  ].join();

  RequestDetailLoaded withNotice(MyRequestsNotice? notice) =>
      RequestDetailLoaded(request, canCancel: canCancel, washerLate: washerLate, notice: notice);

  RequestDetailLoaded withCancelling() =>
      RequestDetailLoaded(request, canCancel: canCancel, washerLate: washerLate, cancelling: true);
}
