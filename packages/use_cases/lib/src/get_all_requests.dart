import 'ports/wash_request_repository.dart';
import 'request_query.dart';

final class GetAllRequests {
  const GetAllRequests({required this.requests});

  static const pageSize = 50;

  final WashRequestRepository requests;

  Future<RequestPage> call({int offset = 0, int limit = pageSize, RequestStatusFilter? status}) =>
      requests.list(RequestQuery(scope: RequestScope.all, limit: limit, offset: offset, status: status));
}
