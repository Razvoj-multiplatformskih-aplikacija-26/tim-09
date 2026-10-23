part of 'my_requests_bloc.dart';

sealed class MyRequestsEvent {
  const MyRequestsEvent();
}

/// Prvo učitavanje i „Pokušaj ponovo“.
final class MyRequestsRequested extends MyRequestsEvent {
  const MyRequestsRequested();
}

final class RequestCancellationRequested extends MyRequestsEvent {
  const RequestCancellationRequested(this.id, {this.reason = ''});

  final WashRequestId id;
  final String reason;
}

/// Ekran je prikazao poruku (SnackBar), pa je Bloc briše iz stanja.
final class MyRequestsNoticeAcknowledged extends MyRequestsEvent {
  const MyRequestsNoticeAcknowledged();
}
