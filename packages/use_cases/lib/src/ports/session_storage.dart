abstract interface class SessionStorage {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> delete();
}
