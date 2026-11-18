import 'dart:isolate';

import 'package:api_mapping/api_mapping.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:contracts/contracts.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';
import 'package:use_cases/use_cases.dart';

import '../api_exception.dart';
import '../config.dart';
import '../security.dart';

final class ServerSession {
  const ServerSession({required this.user, required this.expiresAt, required this.tokenHash, required this.transport});

  final User user;
  final DateTime expiresAt;
  final String tokenHash;
  final String transport;

  SessionDto get dto => SessionDto(user: userToDto(user), expiresAt: expiresAt);
}

final class LoginResult {
  const LoginResult({required this.session, required this.token});

  final ServerSession session;
  final String token;

  SessionDto get dto => SessionDto(
    user: userToDto(session.user),
    expiresAt: session.expiresAt,
    token: session.transport == 'bearer' ? token : null,
  );
}

final class AuthService {
  const AuthService({required this.database, required this.config, this.clock = const SystemClock()});

  final Pool<void> database;
  final ServerConfig config;
  final Clock clock;

  Future<LoginResult> login(LoginRequest input) async {
    final application = ClientApplication.values.where((item) => item.name == input.application).firstOrNull;
    if (application == null || !{'bearer', 'cookie'}.contains(input.sessionTransport)) {
      throw ApiException(400, 'invalid_request');
    }
    final rows = await database.execute(
      Sql.named('''
      SELECT u.*, w.id AS washer_id FROM users u
      LEFT JOIN washers w ON w.user_id = u.id WHERE u.username = @username
    '''),
      parameters: {'username': input.username.trim()},
    );
    if (rows.isEmpty) throw ApiException(401, 'invalid_credentials');
    final row = rows.single.toColumnMap();
    final hash = row['password_hash'] as String;
    final valid = await Isolate.run(() => BCrypt.checkpw(input.password, hash));
    if (!valid) throw ApiException(401, 'invalid_credentials');
    final user = _user(row);
    if (!maySignIn(user, application)) {
      throw ApiException(403, 'wrong_application', {
        'application': application.name,
        'requiredRole': application == ClientApplication.backoffice ? 'dispatcher' : 'client_or_washer',
      });
    }
    final token = randomToken();
    final now = clock.now().toUtc();
    final session = ServerSession(
      user: user,
      expiresAt: now.add(config.sessionTtl),
      tokenHash: tokenHash(token),
      transport: input.sessionTransport,
    );
    await database.execute(
      Sql.named('''
      INSERT INTO sessions (token_hash, user_id, application, transport, created_at, expires_at)
      VALUES (@hash, @userId, @application, @transport, @createdAt, @expiresAt)
    '''),
      parameters: {
        'hash': session.tokenHash,
        'userId': user.id.value,
        'application': application.name,
        'transport': input.sessionTransport,
        'createdAt': now,
        'expiresAt': session.expiresAt,
      },
    );
    return LoginResult(session: session, token: token);
  }

  Future<ServerSession> authenticate(String token, String transport) async {
    final rows = await database.execute(
      Sql.named('''
      SELECT s.token_hash, s.expires_at, s.revoked_at, s.transport,
             u.id, u.username, u.role, w.id AS washer_id
      FROM sessions s JOIN users u ON u.id = s.user_id
      LEFT JOIN washers w ON w.user_id = u.id WHERE s.token_hash = @hash
    '''),
      parameters: {'hash': tokenHash(token)},
    );
    if (rows.isEmpty) throw ApiException(401, 'unauthenticated');
    final row = rows.single.toColumnMap();
    if (row['transport'] != transport) throw ApiException(401, 'unauthenticated');
    if (row['revoked_at'] != null) throw ApiException(401, 'session_revoked');
    final expiresAt = row['expires_at'] as DateTime;
    if (!clock.now().isBefore(expiresAt)) throw ApiException(401, 'session_expired');
    return ServerSession(
      user: _user(row),
      expiresAt: expiresAt,
      tokenHash: row['token_hash'] as String,
      transport: transport,
    );
  }

  Future<void> logout(ServerSession session) async {
    await database.execute(
      Sql.named('UPDATE sessions SET revoked_at = @now WHERE token_hash = @hash'),
      parameters: {'now': clock.now().toUtc(), 'hash': session.tokenHash},
    );
  }

  User _user(Map<String, Object?> row) => User(
    id: UserId(row['id'] as String),
    username: row['username'] as String,
    role: Role.values.byName(row['role'] as String),
    washerId: row['washer_id'] == null ? null : WasherId(row['washer_id'] as String),
  );
}
