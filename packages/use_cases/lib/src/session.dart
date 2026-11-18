import 'package:domain/domain.dart';
import 'package:meta/meta.dart';

@immutable
final class Session {
  const Session({required this.user, required this.expiresAt});

  final User user;
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) => other is Session && other.user == user && other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(user, expiresAt);

  @override
  String toString() => 'Session(${user.username}, ${user.role.name})';
}

enum LoginFailure { invalidCredentials, wrongApplication }

final class LoginRejected implements Exception {
  const LoginRejected(this.reason);

  final LoginFailure reason;

  @override
  String toString() => 'LoginRejected(${reason.name})';
}
