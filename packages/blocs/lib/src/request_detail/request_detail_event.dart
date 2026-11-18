part of 'request_detail_bloc.dart';

sealed class RequestDetailEvent {
  const RequestDetailEvent();
}

final class RequestDetailRequested extends RequestDetailEvent {
  const RequestDetailRequested({this.quiet = false});

  final bool quiet;
}

final class RequestDetailCancelRequested extends RequestDetailEvent {
  const RequestDetailCancelRequested({this.reason = ''});

  final String reason;
}

final class RequestDetailNoticeAcknowledged extends RequestDetailEvent {
  const RequestDetailNoticeAcknowledged();
}
