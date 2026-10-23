import 'package:domain/domain.dart';

import '../wash_request_draft.dart';

/// Port: odakle stižu zahtevi. U KT1 ga implementira lažni repozitorijum u aplikaciji, od KT2 server.
abstract interface class WashRequestRepository {
  Future<List<WashRequest>> requestsOf(UserId clientId);

  Future<WashRequest?> find(WashRequestId id);

  Future<WashRequest> create(WashRequestDraft draft);

  Future<WashRequest> save(WashRequest request);
}
