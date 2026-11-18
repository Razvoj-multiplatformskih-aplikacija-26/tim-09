import 'package:domain/domain.dart';

import 'ports/wash_request_repository.dart';

final class AcceptRequest {
  const AcceptRequest({required this.requests});

  final WashRequestRepository requests;

  Future<Result<WashRequest>> call({required WashRequestId id, required WasherId washer}) =>
      requests.assign(id: id, washerId: washer);
}
