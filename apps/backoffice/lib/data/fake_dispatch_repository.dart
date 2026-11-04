import 'package:domain/domain.dart';
import 'package:use_cases/use_cases.dart';

import 'seed.dart';

/// Lažna implementacija porta: svi zahtevi u memoriji, sa kašnjenjem kao da idu preko mreže.
final class FakeDispatchRepository implements WashRequestRepository {
  FakeDispatchRepository({required this.clock, this.latency = const Duration(milliseconds: 700)})
    : _requests = seedRequests(clock.now());

  final Clock clock;
  final Duration latency;
  final List<WashRequest> _requests;

  /// Koliko sledećih zahteva baca grešku („Simuliraj grešku“).
  int failingRequests = 0;

  /// Koliko sledećih odgovora je prazno („Simuliraj prazan odgovor“).
  int emptyResponses = 0;

  Future<void> _roundTrip() async {
    await Future<void>.delayed(latency);
    if (failingRequests > 0) {
      failingRequests--;
      throw const RepositoryException('Simulated outage');
    }
  }

  @override
  Future<List<WashRequest>> allRequests() async {
    await _roundTrip();
    if (emptyResponses > 0) {
      emptyResponses--;
      return [];
    }
    return List.of(_requests);
  }

  @override
  Future<List<WashRequest>> requestsOf(UserId clientId) async {
    await _roundTrip();
    return _requests.where((r) => r.clientId == clientId).toList();
  }

  @override
  Future<WashRequest?> find(WashRequestId id) async {
    await _roundTrip();
    return _requests.where((r) => r.id == id).firstOrNull;
  }

  @override
  Future<WashRequest> save(WashRequest request) async {
    await _roundTrip();
    _requests[_requests.indexWhere((r) => r.id == request.id)] = request;
    return request;
  }

  @override
  Future<WashRequest> create(WashRequestDraft draft) => throw UnsupportedError('Backoffice ne pravi nove zahteve.');
}
