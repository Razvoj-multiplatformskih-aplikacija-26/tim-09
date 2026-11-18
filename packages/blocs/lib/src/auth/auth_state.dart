part of 'auth_bloc.dart';

enum AuthNotice { invalidCredentials, wrongApplication, unavailable, sessionExpired, logoutFailed }

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => const [];

  @override
  String toString() => '$runtimeType';
}

final class AuthChecking extends AuthState {
  const AuthChecking();
}

final class AuthRestoreFailed extends AuthState {
  const AuthRestoreFailed(this.cause);

  final Object cause;

  @override
  List<Object?> get props => [cause];

  @override
  String toString() => 'AuthRestoreFailed(${cause.runtimeType})';
}

final class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.notice, this.submitting = false});

  final AuthNotice? notice;
  final bool submitting;

  @override
  List<Object?> get props => [notice, submitting];

  @override
  String toString() => 'AuthSignedOut(${[if (submitting) 'submitting', ?notice?.name].join(', ')})';
}

final class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.session, {this.signingOut = false, this.notice});

  final Session session;
  final bool signingOut;
  final AuthNotice? notice;

  @override
  List<Object?> get props => [session, signingOut, notice];

  @override
  String toString() =>
      'AuthSignedIn(${[session.user.username, if (signingOut) 'signing out', ?notice?.name].join(', ')})';
}
