import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import 'support.dart';

void main() {
  testWidgets('cenovnik prikazuje cenu i trajanje za svako vozilo i uslugu iz domena', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byType(NavigationDestination).last);
    await tester.pumpAndSettle();
    expect(find.text('Cena zavisi od vozila i usluge. Perač dolazi na vašu adresu.'), findsOneWidget);

    for (final type in VehicleType.values) {
      for (final tier in ServiceTier.values) {
        final price = estimate(type, tier);
        await tester.scrollUntilVisible(find.textContaining(formatPrice(price.priceRsd)), 200);
        expect(find.textContaining(formatPrice(price.priceRsd)), findsWidgets);
      }
      expect(find.text(type.label), findsOneWidget);
    }
  });
}
