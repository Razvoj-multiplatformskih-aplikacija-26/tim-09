import 'package:domain/domain.dart';

import 'ports/wash_request_repository.dart';

final class GetMyRequests {
  const GetMyRequests({required this.requests});

  final WashRequestRepository requests;

  Future<List<WashRequest>> call(User client) async {
    final mine = await requests.requestsOf(client.id);
    return mine..sort((a, b) => a.slot.start.compareTo(b.slot.start));
  }
}
