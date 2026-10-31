import 'package:domain/domain.dart';
import 'ports/wash_request_repository.dart';

final class GetAllRequests {
  const GetAllRequests({required this.requests});

  final WashRequestRepository requests;

  Future<List<WashRequest>> call() async {
    return await requests.allRequests();
  }
}