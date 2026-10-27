import 'package:domain/domain.dart';
import 'package:use_cases/use_cases.dart';

/// Repozitorijum u memoriji za testove, bez kašnjenja.
final class FakeWashRequests implements WashRequestRepository {
  FakeWashRequests([List<WashRequest>? requests]) : _requests = [...?requests];

  final List<WashRequest> _requests;
  int failingRequests = 0;

  void _maybeFail() {
    if (failingRequests > 0) {
      failingRequests--;
      throw const RepositoryException('Simulated outage');
    }
  }

  @override
  Future<List<WashRequest>> requestsOf(UserId clientId) async {
    _maybeFail();
    return _requests.where((r) => r.clientId == clientId).toList();
  }

  @override
  Future<WashRequest?> find(WashRequestId id) async {
    _maybeFail();
    return _requests.where((r) => r.id == id).firstOrNull;
  }

  @override
  Future<WashRequest> create(WashRequestDraft draft) async {
    _maybeFail();
    final request = WashRequest(
      id: WashRequestId('new-${_requests.length}'),
      clientId: draft.clientId,
      vehicle: draft.vehicle,
      tier: draft.tier,
      address: draft.address,
      slot: draft.slot,
      note: draft.note,
      createdAt: DateTime(2026),
    );
    _requests.add(request);
    return request;
  }

  @override
  Future<WashRequest> save(WashRequest request) async {
    _maybeFail();
    _requests[_requests.indexWhere((r) => r.id == request.id)] = request;
    return request;
  }
}
