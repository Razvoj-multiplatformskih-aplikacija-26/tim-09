import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  group('cena zahteva', () {
    test('bez serverske cene koristi lokalni cenovnik', () {
      final request = requestAt(now.add(const Duration(days: 1)));
      expect(request.price, estimate(VehicleType.sedan, ServiceTier.economy));
    });

    test('serverska cena ima prednost i preživljava promenu stanja', () {
      const quoted = PriceEstimate(priceRsd: 1550, duration: Duration(minutes: 50));
      final base = requestAt(now.add(const Duration(days: 1)));
      final request = WashRequest(
        id: base.id,
        clientId: base.clientId,
        vehicle: base.vehicle,
        tier: base.tier,
        address: base.address,
        slot: base.slot,
        createdAt: base.createdAt,
        quotedPrice: quoted,
      );
      expect(request.price, quoted);
      expect(request.copyWith(status: accepted()).price, quoted);
      expect(request, isNot(base));
      expect(request.hashCode, isNot(base.hashCode));
    });
  });
}
