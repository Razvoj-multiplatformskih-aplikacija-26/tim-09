import 'package:domain/domain.dart';

import '../clock.dart';
import '../ports/wash_request_repository.dart';
import '../ports/washer_repository.dart';
import '../repository_exception.dart';
import '../request_query.dart';
import '../wash_request_draft.dart';

final class InMemoryWashRequests implements WashRequestRepository, WasherRepository {
  InMemoryWashRequests({
    required this.clock,
    required this.currentUser,
    List<WashRequest> requests = const [],
    List<Washer> washers = const [],
    this.latency = Duration.zero,
  }) : _requests = [...requests],
       _washers = [...washers];

  final Clock clock;
  final User? Function() currentUser;
  final Duration latency;
  final List<WashRequest> _requests;
  final List<Washer> _washers;

  int failingRequests = 0;
  int emptyResponses = 0;
  int writes = 0;
  int _nextId = 1;

  List<WashRequest> get all => List.unmodifiable(_requests);

  void replace(WashRequest request) {
    _requests[_requests.indexWhere((r) => r.id == request.id)] = request;
  }

  Future<User> _roundTrip() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (failingRequests > 0) {
      failingRequests--;
      throw const NetworkException('Simulated outage');
    }
    final user = currentUser();
    if (user == null) throw const SessionExpiredException();
    return user;
  }

  List<WashRequest> _visible(User user, RequestScope scope) {
    switch (scope) {
      case RequestScope.all:
        if (!mayViewAllRequests(user)) throw const ProtocolException('Not allowed.', statusCode: 403);
        return List.of(_requests);
      case RequestScope.mine:
        return switch (user.role) {
          Role.client => _requests.where((r) => r.clientId == user.id).toList(),
          Role.washer => _requests.where((r) => r.status.isActive && mayViewRequest(user, r)).toList(),
          Role.dispatcher => throw const ProtocolException('Not allowed.', statusCode: 403),
        };
    }
  }

  @override
  Future<RequestPage> list(RequestQuery query) async {
    final user = await _roundTrip();
    if (emptyResponses > 0) {
      emptyResponses--;
      return RequestPage(items: const [], total: 0, limit: query.limit, offset: query.offset);
    }
    final matching = _visible(user, query.scope).where((r) => matchesStatusFilter(r.status, query.status)).toList()
      ..sort((a, b) {
        final byStart = a.slot.start.compareTo(b.slot.start);
        return byStart != 0 ? byStart : a.id.value.compareTo(b.id.value);
      });
    return RequestPage(
      items: matching.skip(query.offset).take(query.limit).toList(),
      total: matching.length,
      limit: query.limit,
      offset: query.offset,
    );
  }

  @override
  Future<WashRequest?> find(WashRequestId id) async {
    final user = await _roundTrip();
    final request = _requests.where((r) => r.id == id).firstOrNull;
    return request != null && mayViewRequest(user, request) ? request : null;
  }

  @override
  Future<Result<WashRequest>> create(WashRequestDraft draft) async {
    final user = await _roundTrip();
    final result = createWashRequest(
      id: WashRequestId('local-${_nextId++}'),
      by: user,
      vehicleType: draft.vehicle.type,
      plate: draft.vehicle.plate.value,
      tier: draft.tier,
      address: draft.address.text,
      start: draft.slot.start,
      note: draft.note?.text,
      now: clock.now(),
      existing: _requests,
    );
    if (result case Success(:final value)) {
      _requests.add(value);
      writes++;
    }
    return result;
  }

  @override
  Future<Result<WashRequest>> cancel({required WashRequestId id, required String reason}) async {
    final user = await _roundTrip();
    return _write(id, (request) => cancelRequest(request, by: user, now: clock.now(), reason: reason));
  }

  @override
  Future<Result<WashRequest>> assign({required WashRequestId id, required WasherId washerId}) async {
    final user = await _roundTrip();
    if (!mayAssignRequest(user)) return const Failure(NotAllowed());
    if (_washers.isNotEmpty && !_washers.any((w) => w.id == washerId)) return const Failure(NotFound());
    return _write(
      id,
      (request) => acceptRequest(request, washer: washerId, by: user, now: clock.now(), all: _requests),
    );
  }

  @override
  Future<Result<WashRequest>> release({required WashRequestId id}) async {
    final user = await _roundTrip();
    if (!mayReleaseRequest(user)) return const Failure(NotAllowed());
    return _write(id, (request) => releaseRequest(request, by: user));
  }

  @override
  Future<List<Washer>> washers() async {
    final user = await _roundTrip();
    if (!mayAssignRequest(user)) throw const ProtocolException('Not allowed.', statusCode: 403);
    return [
      for (final washer in _washers)
        Washer(id: washer.id, name: washer.name, hasActiveJob: washerHasActiveJob(washer.id, _requests)),
    ];
  }

  Result<WashRequest> _write(WashRequestId id, Result<WashRequest> Function(WashRequest request) change) {
    final request = _requests.where((r) => r.id == id).firstOrNull;
    if (request == null) return const Failure(NotFound());
    final result = change(request);
    if (result case Success(:final value)) {
      replace(value);
      writes++;
    }
    return result;
  }
}
