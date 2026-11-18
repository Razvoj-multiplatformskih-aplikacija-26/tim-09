import 'package:contracts/contracts.dart';
import 'package:domain/domain.dart';

StatusDto statusToDto(WashStatus status) => switch (status) {
  Submitted() => StatusDto(type: 'submitted'),
  Accepted(:final washerId, :final acceptedBy, :final at) => StatusDto(
    type: 'accepted',
    data: {'washerId': washerId.value, 'acceptedBy': acceptedBy.value, 'at': instantJson(at)},
  ),
  InProgress(:final washerId, :final arrivedAt) => StatusDto(
    type: 'in_progress',
    data: {'washerId': washerId.value, 'arrivedAt': instantJson(arrivedAt)},
  ),
  Completed(:final finishedAt) => StatusDto(type: 'completed', data: {'finishedAt': instantJson(finishedAt)}),
  Cancelled(:final reason, :final cancelledBy, :final at) => StatusDto(
    type: 'cancelled',
    data: {'reason': reason, 'cancelledBy': cancelledBy.value, 'at': instantJson(at)},
  ),
};

WashStatus statusFromDto(StatusDto status) => switch (status.type) {
  'submitted' => const Submitted(),
  'accepted' => Accepted(
    washerId: WasherId(jsonString(status.data, 'washerId')),
    acceptedBy: UserId(jsonString(status.data, 'acceptedBy')),
    at: jsonInstant(status.data, 'at'),
  ),
  'in_progress' => InProgress(
    washerId: WasherId(jsonString(status.data, 'washerId')),
    arrivedAt: jsonInstant(status.data, 'arrivedAt'),
  ),
  'completed' => Completed(finishedAt: jsonInstant(status.data, 'finishedAt')),
  'cancelled' => Cancelled(
    reason: jsonString(status.data, 'reason'),
    cancelledBy: UserId(jsonString(status.data, 'cancelledBy')),
    at: jsonInstant(status.data, 'at'),
  ),
  _ => throw const FormatException('Unknown request status.'),
};

WashRequestDto requestToDto(WashRequest request) => WashRequestDto(
  id: request.id.value,
  clientId: request.clientId.value,
  vehicle: VehicleDto(type: request.vehicle.type.name, plate: request.vehicle.plate.value),
  tier: request.tier.name,
  address: request.address.text,
  start: request.slot.start,
  durationMinutes: request.slot.duration.inMinutes,
  createdAt: request.createdAt,
  priceRsd: request.price.priceRsd,
  note: request.note?.text,
  status: statusToDto(request.status),
);

WashRequest requestFromDto(WashRequestDto dto) => WashRequest(
  id: WashRequestId(dto.id),
  clientId: UserId(dto.clientId),
  vehicle: Vehicle(type: _vehicle(dto.vehicle.type), plate: LicensePlate.existing(dto.vehicle.plate)),
  tier: _tier(dto.tier),
  address: Address.existing(dto.address),
  slot: WashSlot.existing(dto.start, Duration(minutes: dto.durationMinutes)),
  createdAt: dto.createdAt,
  note: dto.note == null ? null : WashNote.existing(dto.note!),
  status: statusFromDto(dto.status),
);

Result<WashRequest> createFromDto(
  CreateRequest dto, {
  required WashRequestId id,
  required User by,
  required DateTime now,
  required List<WashRequest> existing,
}) => createWashRequest(
  id: id,
  by: by,
  vehicleType: _vehicle(dto.vehicle.type),
  plate: dto.vehicle.plate,
  tier: _tier(dto.tier),
  address: dto.address,
  start: dto.start,
  note: dto.note,
  now: now,
  existing: existing,
);

VehicleType _vehicle(String value) =>
    VehicleType.values.where((item) => item.name == value).firstOrNull ??
    (throw const FormatException('Unknown vehicle type.'));

ServiceTier _tier(String value) =>
    ServiceTier.values.where((item) => item.name == value).firstOrNull ??
    (throw const FormatException('Unknown service tier.'));
