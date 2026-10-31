import 'package:domain/domain.dart';
import 'ports/wash_request_repository.dart';

final class AcceptRequest {
  const AcceptRequest({required this.requests});

  final WashRequestRepository requests;

  Future<Result<WashRequest>> call({
    required WashRequestId id,
    required WasherId washer,
    required User by,
    required DateTime now,
  }) async {
    final request = await requests.find(id);
    if (request == null) return const Failure(NotFound());

    // Povlačimo sve zahteve da bi domensko pravilo R3 moglo da proveri da li je perač zauzet
    final all = await requests.allRequests();

    final result = acceptRequest(request, washer: washer, by: by, now: now, all: all);
    return switch (result) {
      Failure(:final error) => Failure(error),
      Success(:final value) => Success(await requests.save(value)),
    };
  }
}