import 'package:domain/domain.dart';

final class WashRequestDraft {
  const WashRequestDraft({
    required this.vehicle,
    required this.tier,
    required this.address,
    required this.slot,
    this.note,
  });

  final Vehicle vehicle;
  final ServiceTier tier;
  final Address address;
  final WashSlot slot;
  final WashNote? note;
}
