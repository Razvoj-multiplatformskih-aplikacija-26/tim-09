import 'package:meta/meta.dart';

import 'wash_request/vehicle.dart';

enum ServiceTier { economy, professional }

@immutable
final class PriceEstimate {
  const PriceEstimate({required this.priceRsd, required this.duration});

  final int priceRsd;
  final Duration duration;

  @override
  bool operator ==(Object other) => other is PriceEstimate && other.priceRsd == priceRsd && other.duration == duration;

  @override
  int get hashCode => Object.hash(priceRsd, duration);

  @override
  String toString() => 'PriceEstimate($priceRsd RSD, ${duration.inMinutes} min)';
}

/// Cenovnik: cena zavisi od tipa vozila i nivoa usluge; veća vozila traju duže.
PriceEstimate estimate(VehicleType type, ServiceTier tier) {
  final price = switch ((tier, type)) {
    (ServiceTier.economy, VehicleType.hatchback) => 1200,
    (ServiceTier.economy, VehicleType.sedan) => 1400,
    (ServiceTier.economy, VehicleType.suv) => 1700,
    (ServiceTier.economy, VehicleType.van) => 2000,
    (ServiceTier.professional, VehicleType.hatchback) => 2500,
    (ServiceTier.professional, VehicleType.sedan) => 2900,
    (ServiceTier.professional, VehicleType.suv) => 3500,
    (ServiceTier.professional, VehicleType.van) => 3900,
  };
  final isLarge = type == VehicleType.suv || type == VehicleType.van;
  final minutes = switch (tier) {
    ServiceTier.economy => isLarge ? 60 : 45,
    ServiceTier.professional => isLarge ? 120 : 90,
  };
  return PriceEstimate(
    priceRsd: price,
    duration: Duration(minutes: minutes),
  );
}
