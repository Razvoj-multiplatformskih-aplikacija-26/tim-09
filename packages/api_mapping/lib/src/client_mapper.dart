import 'package:contracts/contracts.dart';
import 'package:use_cases/use_cases.dart';

import 'request_mapper.dart';

CreateRequest draftToDto(WashRequestDraft draft) => CreateRequest(
  vehicle: VehicleDto(type: draft.vehicle.type.name, plate: draft.vehicle.plate.value),
  tier: draft.tier.name,
  address: draft.address.text,
  start: draft.slot.start,
  note: draft.note?.text,
);

RequestPage requestPageFromDto(RequestPageDto page) => RequestPage(
  items: page.items.map(requestFromDto).toList(),
  total: page.total,
  limit: page.limit,
  offset: page.offset,
);

String statusFilterToDto(RequestStatusFilter filter) => switch (filter) {
  RequestStatusFilter.submitted => 'submitted',
  RequestStatusFilter.accepted => 'accepted',
  RequestStatusFilter.inProgress => 'in_progress',
  RequestStatusFilter.completed => 'completed',
  RequestStatusFilter.cancelled => 'cancelled',
};

String scopeToDto(RequestScope scope) => switch (scope) {
  RequestScope.mine => 'mine',
  RequestScope.all => 'all',
};

Map<String, String> queryToDto(RequestQuery query) => {
  'scope': scopeToDto(query.scope),
  'limit': '${query.limit}',
  'offset': '${query.offset}',
  if (query.status case final status?) 'status': statusFilterToDto(status),
};
