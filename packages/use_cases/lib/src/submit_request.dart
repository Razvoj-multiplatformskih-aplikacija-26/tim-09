import 'package:domain/domain.dart';

import 'ports/wash_request_repository.dart';
import 'wash_request_draft.dart';

final class SubmitRequest {
  const SubmitRequest({required this.requests});

  final WashRequestRepository requests;

  Future<Result<WashRequest>> call(WashRequestDraft draft) async {
    final mine = await requests.requestsOf(draft.clientId);
    if (!canSubmit(draft.clientId, mine)) {
      return Failure(
        TooManyPendingRequests(maxPending: maxPendingRequests, currentPending: pendingRequestsOf(draft.clientId, mine)),
      );
    }
    return Success(await requests.create(draft));
  }
}
