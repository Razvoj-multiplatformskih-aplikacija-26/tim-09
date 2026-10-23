import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  Future<void> openForm(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Novi zahtev'));
    await tester.pumpAndSettle();
  }

  testWidgets('loša registarska oznaka prikazuje poruku iz pravila R2', (tester) async {
    await openForm(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Registarska oznaka'), 'BG123');
    await tester.pumpAndSettle();
    expect(find.text('Registarska oznaka mora biti u formatu „BG 123-AB“.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Registarska oznaka'), 'BG 123-AB');
    await tester.pumpAndSettle();
    expect(find.textContaining('mora biti u formatu'), findsNothing);
  });

  testWidgets('napomena od 301 znaka prikazuje poruku iz pravila R1', (tester) async {
    await openForm(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Napomena za perača (nije obavezna)'), 'a' * 301);
    await tester.pumpAndSettle();
    expect(find.text('Napomena može imati najviše 300 znakova.'), findsOneWidget);
  });

  testWidgets('cena se menja sa tipom vozila i uslugom', (tester) async {
    await openForm(tester);
    expect(find.text('1.400 RSD · 45 min'), findsOneWidget);
    await tester.tap(find.text('Profi'));
    await tester.pumpAndSettle();
    expect(find.text('2.900 RSD · 1 h 30 min'), findsOneWidget);
  });
}
