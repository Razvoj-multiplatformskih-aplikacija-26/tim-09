import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  testWidgets('posle učitavanja prikazuje aktivne i prethodne zahteve', (tester) async {
    await pumpApp(tester);
    expect(find.text('Aktivni'), findsOneWidget);
    expect(find.text('Prijavljen'), findsOneWidget);
    expect(find.text('U toku'), findsOneWidget);
  });

  testWidgets('greška pa „Pokušaj ponovo“ vraća podatke', (tester) async {
    final dependencies = await pumpApp(tester);
    await tester.tap(find.byTooltip('Simulacija'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simuliraj grešku'));
    await tester.pumpAndSettle();
    expect(find.text('Podaci trenutno nisu dostupni.'), findsOneWidget);
    expect(dependencies.fakeCarWash!.failingRequests, 0);

    await tester.tap(find.text('Pokušaj ponovo'));
    await tester.pumpAndSettle();
    expect(find.text('Aktivni'), findsOneWidget);
  });

  testWidgets('prazan odgovor prikazuje prazan ekran', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Simulacija'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simuliraj prazan odgovor'));
    await tester.pumpAndSettle();
    expect(find.text('Još nemate zahteva za pranje.'), findsOneWidget);
  });

  testWidgets('otkazivanje traži potvrdu, pa menja stanje u Otkazan', (tester) async {
    await pumpApp(tester);
    expect(find.text('Otkazan'), findsNWidgets(4));
    await tester.tap(find.text('Otkaži').first);
    await tester.pumpAndSettle();
    expect(find.text('Otkazati zahtev?'), findsOneWidget);

    await tester.tap(find.text('Otkaži zahtev'));
    await tester.pumpAndSettle();
    expect(find.text('Zahtev je otkazan.'), findsOneWidget);
    expect(find.text('Otkazan'), findsNWidgets(5));
  });

  testWidgets('dodir na karticu otvara detalj na posebnom ekranu', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Prijavljen'));
    await tester.pumpAndSettle();
    expect(find.text('Zahtev za pranje'), findsOneWidget);
    expect(find.text('Auto je na parkingu iza zgrade.'), findsOneWidget);
  });
}
