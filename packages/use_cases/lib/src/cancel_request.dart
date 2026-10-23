import 'package:domain/domain.dart';

import 'clock.dart';
import 'ports/wash_request_repository.dart';

final class CancelRequest {
  const CancelRequest({required this.requests, required this.clock});

  final WashRequestRepository requests;
  final Clock clock;

  Future<Result<WashRequest>> call({required WashRequestId id, required User by, String reason = ''}) async {
    final request = await requests.find(id);
    if (request == null) return const Failure(NotFound());
    final result = cancelRequest(request, by: by, now: clock.now(), reason: reason);
    return switch (result) {
      Failure(:final error) => Failure(error),
      Success(:final value) => Success(await requests.save(value)),
    };
  }
}
