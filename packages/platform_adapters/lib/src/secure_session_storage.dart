import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:use_cases/use_cases.dart';

final class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage({FlutterSecureStorage? storage}) : _storage = storage ?? _platformStorage();

  static const _key = 'carwash_session_token';

  final FlutterSecureStorage _storage;

  static FlutterSecureStorage _platformStorage() => defaultTargetPlatform == TargetPlatform.macOS
      ? const FlutterSecureStorage(mOptions: MacOsOptions(usesDataProtectionKeychain: false))
      : const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> delete() => _storage.delete(key: _key);

  @override
  String toString() => 'SecureSessionStorage';
}
