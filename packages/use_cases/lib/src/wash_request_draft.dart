import 'package:domain/domain.dart';

/// Podaci za novi zahtev, već provereni pravilima iz domena; ID i vreme dodaje repozitorijum.
final class WashRequestDraft {
  const WashRequestDraft({
    required this.clientId,
    required this.vehicle,
    required this.tier,
    required this.address,
    required this.slot,
    this.note,
  });

  final UserId clientId;
  final Vehicle vehicle;
  final ServiceTier tier;
  final Address address;
  final WashSlot slot;
  final WashNote? note;
}
