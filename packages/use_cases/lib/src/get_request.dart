import 'package:domain/domain.dart';

import 'ports/wash_request_repository.dart';

final class GetRequest {
  const GetRequest({required this.requests});

  final WashRequestRepository requests;

  Future<WashRequest?> call(WashRequestId id) => requests.find(id);
}
