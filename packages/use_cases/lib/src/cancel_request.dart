import 'package:domain/domain.dart';

import 'ports/wash_request_repository.dart';

final class CancelRequest {
  const CancelRequest({required this.requests});

  final WashRequestRepository requests;

  Future<Result<WashRequest>> call({required WashRequestId id, String reason = ''}) =>
      requests.cancel(id: id, reason: reason);
}
