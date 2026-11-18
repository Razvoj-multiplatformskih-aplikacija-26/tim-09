part of 'auth_bloc.dart';

sealed class AuthEvent {
  const AuthEvent();
}

final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

final class AuthLoginSubmitted extends AuthEvent {
  const AuthLoginSubmitted({required this.username, required this.password});

  final String username;
  final String password;

  @override
  String toString() => 'AuthLoginSubmitted($username)';
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

final class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}

final class AuthNoticeAcknowledged extends AuthEvent {
  const AuthNoticeAcknowledged();
}
