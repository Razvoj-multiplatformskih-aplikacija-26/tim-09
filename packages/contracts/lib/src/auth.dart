import 'json_values.dart';

final class UserDto {
  const UserDto({required this.id, required this.username, required this.role, this.washerId});

  factory UserDto.fromJson(Map<String, Object?> json) => UserDto(
    id: jsonString(json, 'id'),
    username: jsonString(json, 'username'),
    role: jsonString(json, 'role'),
    washerId: jsonOptionalString(json, 'washerId'),
  );

  final String id;
  final String username;
  final String role;
  final String? washerId;

  Map<String, Object?> toJson() => {
    'id': id,
    'username': username,
    'role': role,
    if (washerId != null) 'washerId': washerId,
  };
}

final class LoginRequest {
  const LoginRequest({
    required this.username,
    required this.password,
    required this.application,
    required this.sessionTransport,
  });

  factory LoginRequest.fromJson(Map<String, Object?> json) {
    jsonFields(json, {'username', 'password', 'application', 'sessionTransport'});
    return LoginRequest(
      username: jsonString(json, 'username'),
      password: jsonString(json, 'password'),
      application: jsonString(json, 'application'),
      sessionTransport: jsonString(json, 'sessionTransport'),
    );
  }

  final String username;
  final String password;
  final String application;
  final String sessionTransport;

  Map<String, Object?> toJson() => {
    'username': username,
    'password': password,
    'application': application,
    'sessionTransport': sessionTransport,
  };
}

final class SessionDto {
  const SessionDto({required this.user, required this.expiresAt, this.token});

  factory SessionDto.fromJson(Map<String, Object?> json) => SessionDto(
    user: UserDto.fromJson(jsonObject(json['user'])),
    expiresAt: jsonInstant(json, 'expiresAt'),
    token: jsonOptionalString(json, 'token'),
  );

  final UserDto user;
  final DateTime expiresAt;
  final String? token;

  Map<String, Object?> toJson() => {
    'user': user.toJson(),
    'expiresAt': instantJson(expiresAt),
    if (token != null) 'token': token,
  };
}
