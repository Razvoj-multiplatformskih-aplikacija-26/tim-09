import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import 'support.dart';

void main() {
  Future<void> goBack(WidgetTester tester) async {
    final context = tester.element(find.byType(AppBar));
    final tooltip = MaterialLocalizations.of(context).backButtonTooltip;
    await tester.tap(find.byTooltip(tooltip));
  }

  testWidgets('učitavanje je vidljivo dok odgovor ne stigne', (tester) async {
    await pumpApp(tester, latency: const Duration(seconds: 1), settle: false);
    expect(find.byType(ListSkeleton), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Aktivni'), findsOneWidget);
    expect(find.byType(ListSkeleton), findsNothing);
  });

  testWidgets('odustajanje od potvrde ne otkazuje zahtev', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Otkaži').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odustani'));
    await tester.pumpAndSettle();
    expect(find.text('Prijavljen'), findsOneWidget);
    expect(find.text('Otkazan'), findsNWidgets(4));
    expect(find.text('Zahtev je otkazan.'), findsNothing);
  });

  testWidgets('neuspelo otkazivanje čuva zapis i dopušta ponovni pokušaj', (tester) async {
    final dependencies = await pumpApp(tester);
    dependencies.fakeCarWash!.failingRequests = 1;
    await tester.tap(find.text('Otkaži').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otkaži zahtev'));
    await tester.pumpAndSettle();
    expect(find.text('Otkazivanje nije uspelo. Pokušajte ponovo.'), findsOneWidget);
    expect(find.text('Prijavljen'), findsOneWidget);
    await tester.tap(find.text('Otkaži').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otkaži zahtev'));
    await tester.pumpAndSettle();
    expect(find.text('Zahtev je otkazan.'), findsOneWidget);
  });

  testWidgets('pranje u toku nema klijentsko otkazivanje na detalju', (tester) async {
    await pumpApp(tester);
    await tester.ensureVisible(find.text('U toku'));
    await tester.tap(find.text('U toku'));
    await tester.pumpAndSettle();
    expect(find.text('Zahtev za pranje'), findsOneWidget);
    expect(find.text('Otkaži zahtev'), findsNothing);
  });

  testWidgets('navigacija cenovnik, lista i detalj vraća isti tok', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Cenovnik'));
    await tester.pumpAndSettle();
    expect(find.text('Cena zavisi od vozila i usluge. Perač dolazi na vašu adresu.'), findsOneWidget);
    await tester.tap(find.text('Moji zahtevi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prijavljen'));
    await tester.pumpAndSettle();
    expect(find.text('Zahtev za pranje'), findsOneWidget);
    await goBack(tester);
    await tester.pumpAndSettle();
    expect(find.text('Vaša pranja'), findsOneWidget);
  });

  for (final width in [320.0, 360.0, 390.0, 430.0, 768.0]) {
    testWidgets('lista, forma i cenovnik bez prelivanja na širini $width', (tester) async {
      await pumpApp(tester, size: Size(width, 800));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Novi zahtev'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Pošalji zahtev'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await goBack(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cenovnik'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
