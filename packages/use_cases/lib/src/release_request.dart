import 'package:domain/domain.dart';
import 'ports/wash_request_repository.dart';

final class ReleaseRequest {
  const ReleaseRequest({required this.requests});

  final WashRequestRepository requests;

  Future<Result<WashRequest>> call({
    required WashRequestId id,
    required User by,
  }) async {
    final request = await requests.find(id);
    if (request == null) return const Failure(NotFound());

    final result = releaseRequest(request, by: by);
    return switch (result) {
      Failure(:final error) => Failure(error),
      Success(:final value) => Success(await requests.save(value)),
    };
  }
}