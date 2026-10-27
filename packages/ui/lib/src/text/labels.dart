import 'package:domain/domain.dart';

extension WashStatusLabel on WashStatus {
  String get label => switch (this) {
    Submitted() => 'Prijavljen',
    Accepted() => 'Prihvaćen',
    InProgress() => 'U toku',
    Completed() => 'Završen',
    Cancelled() => 'Otkazan',
  };
}

extension VehicleTypeLabel on VehicleType {
  String get label => switch (this) {
    VehicleType.hatchback => 'Hečbek',
    VehicleType.sedan => 'Limuzina',
    VehicleType.suv => 'SUV',
    VehicleType.van => 'Kombi',
  };
}

extension ServiceTierLabel on ServiceTier {
  String get label => switch (this) {
    ServiceTier.economy => 'Ekonomik',
    ServiceTier.professional => 'Profi',
  };
}
