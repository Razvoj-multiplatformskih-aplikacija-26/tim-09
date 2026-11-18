import 'package:domain/domain.dart';

import 'ports/wash_request_repository.dart';

final class ReleaseRequest {
  const ReleaseRequest({required this.requests});

  final WashRequestRepository requests;

  Future<Result<WashRequest>> call({required WashRequestId id}) => requests.release(id: id);
}
