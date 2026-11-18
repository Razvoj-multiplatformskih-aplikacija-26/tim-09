class RepositoryException implements Exception {
  const RepositoryException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

final class NetworkException extends RepositoryException {
  const NetworkException(String message, {this.timedOut = false, this.outcomeUnknown = false, Object? cause})
    : super(message, cause);

  final bool timedOut;
  final bool outcomeUnknown;
}

final class ProtocolException extends RepositoryException {
  const ProtocolException(String message, {this.statusCode, Object? cause}) : super(message, cause);

  final int? statusCode;
}

final class SessionExpiredException extends RepositoryException {
  const SessionExpiredException([super.message = 'Session is no longer valid.']);
}
