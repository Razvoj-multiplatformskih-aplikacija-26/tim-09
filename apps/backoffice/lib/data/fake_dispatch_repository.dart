import 'package:domain/domain.dart';
import 'package:use_cases/use_cases.dart';

import 'seed.dart';

class FakeDispatchRepository implements WashRequestRepository {
  FakeDispatchRepository({required this.clock, this.latency}) : _requests = createInitialRequests(clock);

  final Clock clock;
  final Duration? latency;
  final List<WashRequest> _requests;

  int failingRequests = 0;
  int emptyResponses = 0;

  Future<void> _roundTrip() async {
    if (latency != null) {
      await Future<void>.delayed(latency!);
    }
    if (failingRequests > 0) {
      failingRequests--;
      throw const RepositoryException('Simulirana greška servera.');
    }
  }

  @override
  Future<List<WashRequest>> allRequests() async {
    await _roundTrip();
    if (emptyResponses > 0) {
      emptyResponses--;
      return [];
    }
    return List.unmodifiable(_requests);
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
    final index = _requests.indexWhere((r) => r.id == request.id);
    if (index >= 0) {
      _requests[index] = request;
    } else {
      _requests.add(request);
    }
    return request;
  }

  @override
  Future<WashRequest> create(WashRequestDraft draft) async {
    throw UnimplementedError('Backoffice ne kreira nove zahteve.');
  }
}
