import 'dart:async';

import 'package:domain/domain.dart';

import '../clock.dart';
import '../ports/auth_repository.dart';
import '../ports/session_storage.dart';
import '../repository_exception.dart';
import '../session.dart';

final class InMemoryAuth implements AuthRepository {
  InMemoryAuth({
    required this.application,
    required List<User> users,
    this.clock = const SystemClock(),
    this.password = 'DemoPass123!',
    this.latency = Duration.zero,
    User? signedIn,
  }) : _users = {for (final user in users) user.username: user} {
    if (signedIn != null) _session = _sessionOf(signedIn);
  }

  final ClientApplication application;
  final Clock clock;
  final String password;
  final Duration latency;
  final Map<String, User> _users;
  final _expired = StreamController<void>.broadcast();

  Session? _session;
  int failingRequests = 0;
  int logouts = 0;

  User? get currentUser => _session?.user;

  Session _sessionOf(User user) => Session(user: user, expiresAt: clock.now().add(const Duration(hours: 1)));

  Future<void> _roundTrip() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (failingRequests > 0) {
      failingRequests--;
      throw const NetworkException('Simulated outage');
    }
  }

  @override
  Future<Session?> restore() async {
    await _roundTrip();
    return _session;
  }

  @override
  Future<Session> login({required String username, required String password}) async {
    await _roundTrip();
    final user = _users[username.trim()];
    if (user == null || password != this.password) throw const LoginRejected(LoginFailure.invalidCredentials);
    if (!maySignIn(user, application)) throw const LoginRejected(LoginFailure.wrongApplication);
    return _session = _sessionOf(user);
  }

  @override
  Future<void> logout() async {
    await _roundTrip();
    _session = null;
    logouts++;
  }

  void expire() {
    _session = null;
    _expired.add(null);
  }

  @override
  Stream<void> get sessionExpired => _expired.stream;
}

final class InMemorySessionStorage implements SessionStorage {
  InMemorySessionStorage([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;

  @override
  Future<void> delete() async => token = null;
}
