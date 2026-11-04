import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  Future<void> openForm(WidgetTester tester) async {
    await tester.tap(find.text('Novi zahtev'));
    await tester.pumpAndSettle();
  }

  /// Popunjava formu i šalje je; termin je sutra (27. 10.) u 10:00, koje birač vremena nudi kao početno.
  Future<void> submitRequest(WidgetTester tester, {required String plate}) async {
    await openForm(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Registarska oznaka'), plate);
    await tester.enterText(find.widgetWithText(TextFormField, 'Adresa vozila'), 'Nemanjina 4, Beograd');
    await tester.tap(find.text('Izaberite datum i vreme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('27'));
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pošalji zahtev'));
    await tester.pumpAndSettle();
  }

  testWidgets('loša registarska oznaka prikazuje poruku iz pravila R2', (tester) async {
    await pumpApp(tester);
    await openForm(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Registarska oznaka'), 'BG123');
    await tester.pumpAndSettle();
    expect(find.text('Registarska oznaka mora biti u formatu „BG 123-AB“.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Registarska oznaka'), 'BG 123-AB');
    await tester.pumpAndSettle();
    expect(find.textContaining('mora biti u formatu'), findsNothing);
  });

  testWidgets('napomena od 301 znaka prikazuje poruku iz pravila R1', (tester) async {
    await pumpApp(tester);
    await openForm(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Napomena za perača (nije obavezna)'), 'a' * 301);
    await tester.pumpAndSettle();
    expect(find.text('Napomena može imati najviše 300 znakova.'), findsOneWidget);
  });

  testWidgets('cena se menja sa tipom vozila i uslugom', (tester) async {
    await pumpApp(tester);
    await openForm(tester);
    expect(find.text('1.400 RSD · 45 min'), findsOneWidget);
    await tester.tap(find.text('Profi'));
    await tester.pumpAndSettle();
    expect(find.text('2.900 RSD · 1 h 30 min'), findsOneWidget);
  });

  testWidgets('poslat zahtev se pojavljuje u listi kao prijavljen', (tester) async {
    await pumpApp(tester);
    expect(find.text('Prijavljen'), findsOneWidget);

    await submitRequest(tester, plate: 'bg 777-xy');
    expect(find.text('Zahtev je poslat.'), findsOneWidget);
    expect(find.text('Prijavljen'), findsNWidgets(2));
    expect(find.textContaining('BG 777-XY'), findsOneWidget);
  });

  testWidgets('četvrti zahtev na čekanju se odbija porukom iz pravila R6, odmah', (tester) async {
    await pumpApp(tester);
    await submitRequest(tester, plate: 'BG 777-XY');

    // Bez čekanja da prethodna poruka istekne: nova je zamenjuje.
    await submitRequest(tester, plate: 'BG 778-XY');
    expect(find.text('Možete imati najviše 3 zahteva na čekanju.'), findsOneWidget);
    expect(find.text('Zahtev je poslat.'), findsNothing);
    expect(find.text('Pošalji zahtev'), findsOneWidget);
  });

  testWidgets('kalendar ide po satu aplikacije i nudi samo dane koje pravilo o terminu dozvoljava', (tester) async {
    await pumpApp(tester);
    await openForm(tester);
    await tester.tap(find.text('Izaberite datum i vreme'));
    await tester.pumpAndSettle();
    final picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(picker.currentDate, DateTime(2026, 10, 26));
    expect(picker.firstDate, DateTime(2026, 10, 26));
    expect(picker.lastDate, DateTime(2026, 11, 2));
    expect(find.text('oktobar 2026.'), findsOneWidget);
  });
}
