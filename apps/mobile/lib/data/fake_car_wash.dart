import 'package:domain/domain.dart';
import 'package:use_cases/use_cases.dart';

import 'seed.dart';

/// Lažna implementacija porta: podaci u memoriji, sa kašnjenjem kao da idu preko mreže.
final class FakeCarWash implements WashRequestRepository {
  FakeCarWash({required this.clock, this.latency = const Duration(milliseconds: 700)})
    : _requests = seedRequests(clock.now());

  final Clock clock;
  final Duration latency;
  final List<WashRequest> _requests;

  /// Koliko sledećih zahteva baca grešku („Simuliraj grešku“).
  int failingRequests = 0;

  /// Koliko sledećih odgovora je prazno („Simuliraj prazan odgovor“).
  int emptyResponses = 0;

  int _nextId = 1;

  Future<void> _roundTrip() async {
    await Future<void>.delayed(latency);
    if (failingRequests > 0) {
      failingRequests--;
      throw const RepositoryException('Simulated outage');
    }
  }

  @override
  Future<List<WashRequest>> requestsOf(UserId clientId) async {
    await _roundTrip();
    if (emptyResponses > 0) {
      emptyResponses--;
      return [];
    }
    return _requests.where((r) => r.clientId == clientId).toList();
  }

  @override
  Future<WashRequest?> find(WashRequestId id) async {
    await _roundTrip();
    return _requests.where((r) => r.id == id).firstOrNull;
  }

  @override
  Future<WashRequest> create(WashRequestDraft draft) async {
    await _roundTrip();
    final request = WashRequest(
      id: WashRequestId('local-${_nextId++}'),
      clientId: draft.clientId,
      vehicle: draft.vehicle,
      tier: draft.tier,
      address: draft.address,
      slot: draft.slot,
      note: draft.note,
      createdAt: clock.now(),
    );
    _requests.add(request);
    return request;
  }

  @override
  Future<WashRequest> save(WashRequest request) async {
    await _roundTrip();
    final index = _requests.indexWhere((r) => r.id == request.id);
    _requests[index] = request;
    return request;
  }
}
