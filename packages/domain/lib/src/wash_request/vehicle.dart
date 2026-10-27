import 'package:meta/meta.dart';

import 'license_plate.dart';

enum VehicleType { hatchback, sedan, suv, van }

@immutable
final class Vehicle {
  const Vehicle({required this.type, required this.plate});

  final VehicleType type;
  final LicensePlate plate;

  @override
  bool operator ==(Object other) => other is Vehicle && other.type == type && other.plate == plate;

  @override
  int get hashCode => Object.hash(type, plate);

  @override
  String toString() => 'Vehicle(${type.name}, ${plate.value})';
}
