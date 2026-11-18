import 'dart:async';

enum SessionTransport { bearer, cookie }

final class SessionController {
  SessionController({required this.transport});

  final SessionTransport transport;
  final _expired = StreamController<void>.broadcast();

  String? _token;
  bool _active = false;
  int _generation = 0;

  int get generation => _generation;

  bool get isActive => _active;

  String? get authorization => _active && _token != null ? 'Bearer $_token' : null;

  Stream<void> get expired => _expired.stream;

  void start([String? token]) {
    _generation++;
    _token = token;
    _active = true;
  }

  void clear() {
    _generation++;
    _token = null;
    _active = false;
  }

  bool expire(int generation) {
    if (generation != _generation || !_active) return false;
    clear();
    _expired.add(null);
    return true;
  }

  @override
  String toString() => 'SessionController(${transport.name}, ${_active ? 'active' : 'inactive'})';
}
