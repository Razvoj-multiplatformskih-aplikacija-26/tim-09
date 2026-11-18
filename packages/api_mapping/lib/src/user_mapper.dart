import 'package:contracts/contracts.dart';
import 'package:domain/domain.dart';

UserDto userToDto(User user) =>
    UserDto(id: user.id.value, username: user.username, role: user.role.name, washerId: user.washerId?.value);

User userFromDto(UserDto user) => User(
  id: UserId(user.id),
  username: user.username,
  role:
      Role.values.where((role) => role.name == user.role).firstOrNull ?? (throw const FormatException('Unknown role.')),
  washerId: user.washerId == null ? null : WasherId(user.washerId!),
);

WasherDto washerToDto(Washer washer) =>
    WasherDto(id: washer.id.value, name: washer.name, hasActiveJob: washer.hasActiveJob);

Washer washerFromDto(WasherDto washer) =>
    Washer(id: WasherId(washer.id), name: washer.name, hasActiveJob: washer.hasActiveJob);
