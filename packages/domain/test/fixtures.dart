import 'package:domain/domain.dart';

/// Ponedeljak u 9:00 — „sada“ u svim testovima.
final now = DateTime(2026, 10, 26, 9);

const client = User(id: UserId('u-client'), username: 'marko', role: Role.client);
const otherClient = User(id: UserId('u-other'), username: 'ana', role: Role.client);
const dispatcher = User(id: UserId('u-dispatcher'), username: 'dispecer', role: Role.dispatcher);

WashRequest requestAt(DateTime start, {WashStatus status = const Submitted(), UserId? clientId}) {
  return WashRequest(
    id: const WashRequestId('wr-1'),
    clientId: clientId ?? client.id,
    vehicle: Vehicle(type: VehicleType.sedan, plate: LicensePlate.parse('BG 123-AB').valueOrNull!),
    tier: ServiceTier.economy,
    address: Address.parse('Knez Mihailova 6, Beograd').valueOrNull!,
    slot: WashSlot.existing(start, const Duration(minutes: 45)),
    status: status,
    createdAt: now,
  );
}

Accepted accepted() => Accepted(washerId: const WasherId('w-1'), acceptedBy: dispatcher.id, at: now);
