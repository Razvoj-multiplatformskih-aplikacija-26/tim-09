import 'package:domain/domain.dart';

import '../request_query.dart';
import '../wash_request_draft.dart';

abstract interface class WashRequestRepository {
  Future<RequestPage> list(RequestQuery query);

  Future<WashRequest?> find(WashRequestId id);

  Future<Result<WashRequest>> create(WashRequestDraft draft);

  Future<Result<WashRequest>> cancel({required WashRequestId id, required String reason});

  Future<Result<WashRequest>> assign({required WashRequestId id, required WasherId washerId});

  Future<Result<WashRequest>> release({required WashRequestId id});
}
