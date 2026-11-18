import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:use_cases/use_cases.dart';

part 'auth_event.dart';
part 'auth_state.dart';

final class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required this.auth}) : super(const AuthChecking()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginSubmitted>(_onLoginSubmitted);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthSessionExpired>(_onSessionExpired);
    on<AuthNoticeAcknowledged>(_onNoticeAcknowledged);
    _expirations = auth.sessionExpired.listen((_) => add(const AuthSessionExpired()));
  }

  final AuthRepository auth;
  late final StreamSubscription<void> _expirations;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    emit(const AuthChecking());
    try {
      final session = await auth.restore();
      emit(session == null ? const AuthSignedOut() : AuthSignedIn(session));
    } on SessionExpiredException {
      emit(const AuthSignedOut());
    } on Exception catch (cause) {
      emit(AuthRestoreFailed(cause));
    }
  }

  Future<void> _onLoginSubmitted(AuthLoginSubmitted event, Emitter<AuthState> emit) async {
    final current = state;
    if (current is! AuthSignedOut || current.submitting) return;
    emit(const AuthSignedOut(submitting: true));
    try {
      emit(AuthSignedIn(await auth.login(username: event.username, password: event.password)));
    } on LoginRejected catch (rejection) {
      emit(
        AuthSignedOut(
          notice: switch (rejection.reason) {
            LoginFailure.invalidCredentials => AuthNotice.invalidCredentials,
            LoginFailure.wrongApplication => AuthNotice.wrongApplication,
          },
        ),
      );
    } on Exception {
      emit(const AuthSignedOut(notice: AuthNotice.unavailable));
    }
  }

  Future<void> _onLogoutRequested(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    final current = state;
    if (current is! AuthSignedIn || current.signingOut) return;
    emit(AuthSignedIn(current.session, signingOut: true));
    try {
      await auth.logout();
      emit(const AuthSignedOut());
    } on SessionExpiredException {
      emit(const AuthSignedOut());
    } on Exception {
      emit(AuthSignedIn(current.session, notice: AuthNotice.logoutFailed));
    }
  }

  void _onSessionExpired(AuthSessionExpired event, Emitter<AuthState> emit) {
    if (state is AuthSignedIn) emit(const AuthSignedOut(notice: AuthNotice.sessionExpired));
  }

  void _onNoticeAcknowledged(AuthNoticeAcknowledged event, Emitter<AuthState> emit) {
    switch (state) {
      case AuthSignedOut(:final submitting, notice: _?):
        emit(AuthSignedOut(submitting: submitting));
      case AuthSignedIn(:final session, :final signingOut, notice: _?):
        emit(AuthSignedIn(session, signingOut: signingOut));
      default:
        break;
    }
  }

  @override
  Future<void> close() async {
    await _expirations.cancel();
    return super.close();
  }
}
