import '../session.dart';

abstract interface class AuthRepository {
  Future<Session?> restore();

  Future<Session> login({required String username, required String password});

  Future<void> logout();

  Stream<void> get sessionExpired;
}
