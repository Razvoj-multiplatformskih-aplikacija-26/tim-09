import 'ports/wash_request_repository.dart';
import 'request_query.dart';

final class GetMyRequests {
  const GetMyRequests({required this.requests});

  static const pageSize = 20;

  final WashRequestRepository requests;

  Future<RequestPage> call({int offset = 0, int limit = pageSize, RequestStatusFilter? status}) =>
      requests.list(RequestQuery(scope: RequestScope.mine, limit: limit, offset: offset, status: status));
}
