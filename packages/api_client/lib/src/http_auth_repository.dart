import 'dart:async';

import 'package:api_mapping/api_mapping.dart';
import 'package:contracts/contracts.dart';
import 'package:domain/domain.dart';
import 'package:use_cases/use_cases.dart';

import 'car_wash_api.dart';
import 'session_controller.dart';

final class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({required this.api, required this.application, this.storage})
    : assert(api.session.transport == SessionTransport.cookie || storage != null) {
    _expirations = api.session.expired.listen((_) => unawaited(storage?.delete()));
  }

  final CarWashApi api;
  final ClientApplication application;
  final SessionStorage? storage;
  late final StreamSubscription<void> _expirations;

  SessionController get _session => api.session;

  bool get _bearer => _session.transport == SessionTransport.bearer;

  @override
  Stream<void> get sessionExpired => _session.expired;

  @override
  Future<Session?> restore() async {
    if (_bearer) {
      final token = await storage!.read();
      if (token == null) return null;
      _session.start(token);
    } else {
      _session.start();
    }
    final result = await api.get('/auth/me', reportsExpiry: false);
    switch (result) {
      case ApiOk(:final json):
        return readContract(json, (json) => _sessionOf(SessionDto.fromJson(json)));
      case ApiRejected(status: 401):
        await _forget();
        return null;
      case ApiRejected(:final status, :final error):
        throw ProtocolException(error.code, statusCode: status);
    }
  }

  @override
  Future<Session> login({required String username, required String password}) async {
    final body = LoginRequest(
      username: username.trim(),
      password: password,
      application: application.name,
      sessionTransport: _session.transport.name,
    );
    final result = await api.post('/auth/login', body: body.toJson(), authenticated: false);
    switch (result) {
      case ApiOk(:final json):
        final dto = readContract(json, SessionDto.fromJson);
        final session = readContract(json, (_) => _sessionOf(dto));
        if (_bearer) {
          final token = dto.token;
          if (token == null || token.isEmpty) throw const ProtocolException('Login response has no token.');
          await storage!.write(token);
          _session.start(token);
        } else {
          _session.start();
        }
        return session;
      case ApiRejected(error: ApiError(code: 'invalid_credentials')):
        throw const LoginRejected(LoginFailure.invalidCredentials);
      case ApiRejected(error: ApiError(code: 'wrong_application')):
        throw const LoginRejected(LoginFailure.wrongApplication);
      case ApiRejected(:final status, :final error):
        throw ProtocolException(error.code, statusCode: status);
    }
  }

  @override
  Future<void> logout() async {
    final result = await api.post('/auth/logout', reportsExpiry: false);
    switch (result) {
      case ApiOk() || ApiRejected(status: 401):
        await _forget();
      case ApiRejected(:final status, :final error):
        throw ProtocolException(error.code, statusCode: status);
    }
  }

  Future<void> _forget() async {
    _session.clear();
    await storage?.delete();
  }

  Session _sessionOf(SessionDto dto) => Session(user: userFromDto(dto.user), expiresAt: dto.expiresAt);

  Future<void> dispose() => _expirations.cancel();
}
