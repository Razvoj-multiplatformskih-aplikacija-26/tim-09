import 'package:domain/domain.dart';

final class RequestPage {
  const RequestPage({required this.items, required this.total, required this.limit, required this.offset});

  final List<WashRequest> items;
  final int total;
  final int limit;
  final int offset;
}

abstract interface class RequestStore {
  Future<RequestPage> list({
    UserId? clientId,
    WasherId? washerId,
    String? status,
    required int limit,
    required int offset,
  });
  Future<WashRequest?> find(WashRequestId id);
  Future<List<WashRequest>> activeJobs();
  Future<List<({WasherId id, String name})>> washers();
  Future<T> transaction<T>(Future<T> Function(RequestTransaction transaction) action);
}

abstract interface class RequestTransaction {
  Future<void> lockClient(UserId id);
  Future<bool> lockWasher(WasherId id);
  Future<WashRequest?> lockRequest(WashRequestId id);
  Future<List<WashRequest>> requestsOf(UserId clientId);
  Future<List<WashRequest>> activeJobs();
  Future<void> insert(WashRequest request, {double? latitude, double? longitude});
  Future<void> update(WashRequest request);
}
