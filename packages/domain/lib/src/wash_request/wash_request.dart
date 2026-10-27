import 'package:meta/meta.dart';

import '../identifiers.dart';
import '../pricing.dart';
import 'address.dart';
import 'vehicle.dart';
import 'wash_note.dart';
import 'wash_slot.dart';
import 'wash_status.dart';

/// Glavni pojam: zahtev klijenta da mu se opere vozilo na adresi, u terminu.
@immutable
final class WashRequest {
  const WashRequest({
    required this.id,
    required this.clientId,
    required this.vehicle,
    required this.tier,
    required this.address,
    required this.slot,
    required this.createdAt,
    this.note,
    this.status = const Submitted(),
  });

  final WashRequestId id;
  final UserId clientId;
  final Vehicle vehicle;
  final ServiceTier tier;
  final Address address;
  final WashSlot slot;
  final WashNote? note;
  final WashStatus status;
  final DateTime createdAt;

  PriceEstimate get price => estimate(vehicle.type, tier);

  bool get isActive => status.isActive;

  WashRequest copyWith({WashStatus? status}) {
    return WashRequest(
      id: id,
      clientId: clientId,
      vehicle: vehicle,
      tier: tier,
      address: address,
      slot: slot,
      createdAt: createdAt,
      note: note,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WashRequest &&
      other.id == id &&
      other.clientId == clientId &&
      other.vehicle == vehicle &&
      other.tier == tier &&
      other.address == address &&
      other.slot == slot &&
      other.note == note &&
      other.status == status &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, clientId, vehicle, tier, address, slot, note, status, createdAt);

  @override
  String toString() => 'WashRequest($id, ${slot.start.toIso8601String()}, $status)';
}
