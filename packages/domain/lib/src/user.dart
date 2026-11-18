import 'package:meta/meta.dart';

import 'identifiers.dart';

enum Role {
  client,
  washer,
  dispatcher;

  bool get isStaff => this == Role.dispatcher;
}

@immutable
final class User {
  const User({required this.id, required this.username, required this.role, this.washerId});

  final UserId id;
  final String username;
  final Role role;
  final WasherId? washerId;

  @override
  bool operator ==(Object other) =>
      other is User && other.id == id && other.username == username && other.role == role && other.washerId == washerId;

  @override
  int get hashCode => Object.hash(id, username, role, washerId);

  @override
  String toString() => 'User($username, ${role.name})';
}
