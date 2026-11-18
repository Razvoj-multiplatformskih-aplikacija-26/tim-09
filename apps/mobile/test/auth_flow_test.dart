import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/screens/my_requests_screen.dart';

import 'support.dart';

void main() {
  testWidgets('bez sesije prikazuje prijavu, a cenovnik ostaje javan', (tester) async {
    await pumpApp(tester, signedIn: null);
    expect(find.text('Prijavite se kao klijent ili perač.'), findsOneWidget);
    expect(find.text('Vaša pranja'), findsNothing);
    await tester.tap(find.text('Cenovnik'));
    await tester.pumpAndSettle();
    expect(find.text('Cena zavisi od vozila i usluge. Perač dolazi na vašu adresu.'), findsOneWidget);
  });

  testWidgets('prijava klijenta otvara njegove zahteve', (tester) async {
    await pumpApp(tester, signedIn: null);
    await signIn(tester, 'marko');
    expect(find.text('Zdravo, Marko · Klijent'), findsOneWidget);
    expect(find.text('Aktivni'), findsOneWidget);
    expect(find.text('Novi zahtev'), findsOneWidget);
  });

  testWidgets('pogrešna lozinka i pogrešna aplikacija imaju posebne poruke, unos ostaje', (tester) async {
    await pumpApp(tester, signedIn: null);
    await signIn(tester, 'marko', password: 'pogresno');
    expect(find.text('Pogrešno korisničko ime ili lozinka.'), findsOneWidget);
    await signIn(tester, 'dispecer');
    expect(find.text('Mobilna aplikacija je namenjena klijentima i peračima.'), findsOneWidget);
    final field = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Korisničko ime'));
    expect(field.controller!.text, 'dispecer');
  });

  testWidgets('nedostupan server pri prijavi završava učitavanje i dopušta ponovni pokušaj', (tester) async {
    final dependencies = await pumpApp(tester, signedIn: null);
    dependencies.fakeAuth!.failingRequests = 1;
    await signIn(tester, 'marko');
    expect(find.text('Prijava trenutno nije moguća. Proverite vezu i pokušajte ponovo.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Prijavi se'));
    await tester.pumpAndSettle();
    expect(find.text('Aktivni'), findsOneWidget);
  });

  testWidgets('odjava uklanja podatke; drugi klijent ne vidi tuđe zahteve', (tester) async {
    final dependencies = await pumpApp(tester);
    expect(find.text('Aktivni'), findsOneWidget);
    await tester.tap(find.byTooltip('Nalog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odjavi se'));
    await tester.pumpAndSettle();
    expect(find.text('Prijavite se kao klijent ili perač.'), findsOneWidget);
    expect(dependencies.fakeAuth!.logouts, 1);

    await signIn(tester, 'ana');
    expect(find.text('Zdravo, Ana · Klijent'), findsOneWidget);
    expect(find.text('Još nemate zahteva za pranje.'), findsOneWidget);
    expect(find.text('Auto je na parkingu iza zgrade.'), findsNothing);
  });

  testWidgets('neuspešna odjava ostavlja korisnika prijavljenog uz poruku', (tester) async {
    final dependencies = await pumpApp(tester);
    dependencies.fakeAuth!.failingRequests = 1;
    await tester.tap(find.byTooltip('Nalog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odjavi se'));
    await tester.pumpAndSettle();
    expect(find.text('Odjava nije potvrđena. Proverite vezu i pokušajte ponovo.'), findsOneWidget);
    expect(find.text('Vaša pranja'), findsOneWidget);
  });

  testWidgets('istek sesije vraća na prijavu uz poruku', (tester) async {
    final dependencies = await pumpApp(tester);
    dependencies.fakeAuth!.expire();
    await tester.pumpAndSettle();
    expect(find.text('Prijava je istekla. Prijavite se ponovo.'), findsOneWidget);
    expect(find.text('Vaša pranja'), findsNothing);
  });

  testWidgets('perač vidi dodeljeni aktivni posao, bez kreiranja i klijentskog otkazivanja', (tester) async {
    await pumpApp(tester, signedIn: washerUser);
    expect(find.text('Vaši poslovi'), findsOneWidget);
    expect(find.text('Moji poslovi'), findsOneWidget);
    expect(find.text('Novi zahtev'), findsNothing);
    expect(find.text('Prihvaćen'), findsOneWidget);
    expect(find.text('Prijavljen'), findsNothing);
    expect(find.text('Otkaži'), findsNothing);
  });

  testWidgets('perač ne može ni direktnom adresom do forme za novi zahtev', (tester) async {
    await pumpApp(tester, signedIn: washerUser);
    GoRouter.of(tester.element(find.byType(MyRequestsScreen))).go('/new');
    await tester.pumpAndSettle();
    expect(find.text('Pošalji zahtev'), findsNothing);
    expect(find.text('Vaši poslovi'), findsOneWidget);
  });

  testWidgets('detalj po direktnoj adresi: tuđ ili nepostojeći zapis je nedostupan', (tester) async {
    await pumpApp(tester);
    unawaited(GoRouter.of(tester.element(find.byType(MyRequestsScreen))).push('/requests/nema'));
    await tester.pumpAndSettle();
    expect(find.text('Zahtev nije pronađen ili nije dostupan.'), findsOneWidget);
  });

  testWidgets('otkazivanje sa detalja osvežava detalj i listu', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Prijavljen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otkaži zahtev'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otkaži zahtev').last);
    await tester.pumpAndSettle();
    expect(find.text('Zahtev je otkazan.'), findsOneWidget);
    expect(find.text('Otkazan'), findsOneWidget);
    expect(find.text('Otkaži zahtev'), findsNothing);
  });
}
