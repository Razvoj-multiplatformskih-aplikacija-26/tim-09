import 'package:domain/domain.dart';
import 'package:use_cases/use_cases.dart';

LicensePlate _parsePlate(String input) {
  final result = LicensePlate.parse(input);
  if (result is Success<LicensePlate>) {
    return result.value;
  }
  throw ArgumentError('Invalid license plate: $input');
}

Address _parseAddress(String input) {
  final result = Address.parse(input);
  if (result is Success<Address>) {
    return result.value;
  }
  throw ArgumentError('Invalid address: $input');
}

List<WashRequest> createInitialRequests(Clock clock) {
  final now = clock.now();
  return [
    WashRequest(
      id: const WashRequestId('req-1'),
      clientId: const UserId('client-1'),
      vehicle: Vehicle(type: VehicleType.sedan, plate: _parsePlate('BG 123-AB')),
      tier: ServiceTier.values[0],
      address: _parseAddress('Kneza Miloša 1, Beograd'),
      slot: WashSlot.existing(DateTime(now.year, now.month, now.day, 10, 0), const Duration(hours: 1)),
      status: const Submitted(),
      createdAt: now,
    ),
    WashRequest(
      id: const WashRequestId('req-2'),
      clientId: const UserId('client-2'),
      vehicle: Vehicle(type: VehicleType.suv, plate: _parsePlate('NS 456-CD')),
      tier: ServiceTier.values.length > 1 ? ServiceTier.values[1] : ServiceTier.values[0],
      address: _parseAddress('Bulevar Oslobođenja 15, Novi Sad'),
      slot: WashSlot.existing(DateTime(now.year, now.month, now.day, 12, 30), const Duration(hours: 1)),
      status: Accepted(washerId: const WasherId('w-1'), acceptedBy: const UserId('u-dispatcher'), at: now),
      createdAt: now,
    ),
    WashRequest(
      id: const WashRequestId('req-3'),
      clientId: const UserId('client-3'),
      vehicle: Vehicle(type: VehicleType.van, plate: _parsePlate('NI 789-EF')),
      tier: ServiceTier.values.length > 2 ? ServiceTier.values[2] : ServiceTier.values[0],
      address: _parseAddress('Obrenovićeva 42, Niš'),
      slot: WashSlot.existing(DateTime(now.year, now.month, now.day, 15, 0), const Duration(hours: 1)),
      status: InProgress(washerId: const WasherId('w-2'), arrivedAt: now),
      createdAt: now,
    ),
  ];
}
