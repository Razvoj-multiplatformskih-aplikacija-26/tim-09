import 'package:domain/domain.dart';

WashRequest requestFromRow(Map<String, Object?> row) {
  final status = switch (row['status']) {
    'submitted' => const Submitted(),
    'accepted' => Accepted(
      washerId: WasherId(row['washer_id'] as String),
      acceptedBy: UserId(row['accepted_by'] as String),
      at: row['accepted_at'] as DateTime,
    ),
    'in_progress' => InProgress(
      washerId: WasherId(row['washer_id'] as String),
      arrivedAt: row['arrived_at'] as DateTime,
    ),
    'completed' => Completed(finishedAt: row['finished_at'] as DateTime),
    'cancelled' => Cancelled(
      reason: row['cancel_reason'] as String,
      cancelledBy: UserId(row['cancelled_by'] as String),
      at: row['cancelled_at'] as DateTime,
    ),
    _ => throw StateError('Unknown stored status.'),
  };
  return WashRequest(
    id: WashRequestId(row['id'] as String),
    clientId: UserId(row['client_id'] as String),
    vehicle: Vehicle(
      type: VehicleType.values.byName(row['vehicle_type'] as String),
      plate: LicensePlate.existing(row['plate'] as String),
    ),
    tier: ServiceTier.values.byName(row['tier'] as String),
    address: Address.existing(row['address'] as String),
    slot: WashSlot.existing(row['start_at'] as DateTime, Duration(minutes: row['duration_minutes'] as int)),
    note: row['note'] == null ? null : WashNote.existing(row['note'] as String),
    status: status,
    createdAt: row['created_at'] as DateTime,
  );
}

Map<String, Object?> requestParameters(WashRequest request) => {
  'id': request.id.value,
  'clientId': request.clientId.value,
  'vehicleType': request.vehicle.type.name,
  'plate': request.vehicle.plate.value,
  'tier': request.tier.name,
  'address': request.address.text,
  'start': request.slot.start.toUtc(),
  'duration': request.slot.duration.inMinutes,
  'note': request.note?.text,
  'createdAt': request.createdAt.toUtc(),
  ...switch (request.status) {
    Submitted() => {'status': 'submitted'},
    Accepted(:final washerId, :final acceptedBy, :final at) => {
      'status': 'accepted',
      'washerId': washerId.value,
      'acceptedBy': acceptedBy.value,
      'acceptedAt': at.toUtc(),
    },
    InProgress(:final washerId, :final arrivedAt) => {
      'status': 'in_progress',
      'washerId': washerId.value,
      'arrivedAt': arrivedAt.toUtc(),
    },
    Completed(:final finishedAt) => {'status': 'completed', 'finishedAt': finishedAt.toUtc()},
    Cancelled(:final reason, :final cancelledBy, :final at) => {
      'status': 'cancelled',
      'cancelReason': reason,
      'cancelledBy': cancelledBy.value,
      'cancelledAt': at.toUtc(),
    },
  },
};

const statusFields = [
  'washerId',
  'acceptedBy',
  'acceptedAt',
  'arrivedAt',
  'finishedAt',
  'cancelReason',
  'cancelledBy',
  'cancelledAt',
];

Map<String, Object?> completeRequestParameters(WashRequest request) => {
  for (final field in statusFields) field: null,
  ...requestParameters(request),
};
