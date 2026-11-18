import 'package:backoffice/app.dart';
import 'package:backoffice/config.dart';
import 'package:backoffice/dependencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ui/ui.dart';

Future<void> startApp(WidgetTester tester) async {
  await tester.pumpWidget(SizedBox.shrink(key: UniqueKey()));
  await tester.pumpWidget(BackofficeApp(dependencies: BackofficeDependencies.network(baseUrl: apiBaseUrl())));
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.byType(CheckingView).evaluate().isEmpty && find.byType(ListSkeleton).evaluate().isEmpty) break;
  }
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('desktop: prijava, obnova posle ponovnog pokretanja i odjava nad stvarnim serverom', (tester) async {
    await initializeDateFormatting(serbianLatin);
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;

    await startApp(tester);
    if (find.byIcon(Icons.logout).evaluate().isNotEmpty) {
      await tester.tap(find.byIcon(Icons.logout));
      await settle(tester);
    }
    expect(find.text('CarWash & Go · prijava za dispečere'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Korisničko ime'), 'dispecer');
    await tester.enterText(find.widgetWithText(TextFormField, 'Lozinka'), 'DemoPass123!');
    await tester.tap(find.widgetWithText(FilledButton, 'Prijavi se'));
    await settle(tester);
    expect(find.text('Dispečerska tabla'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);

    await startApp(tester);
    expect(find.byIcon(Icons.logout), findsOneWidget, reason: 'token iz bezbednog skladišta obnavlja prijavu');

    await tester.tap(find.byIcon(Icons.logout));
    await settle(tester);
    expect(find.text('CarWash & Go · prijava za dispečere'), findsOneWidget);

    await startApp(tester);
    expect(find.text('CarWash & Go · prijava za dispečere'), findsOneWidget, reason: 'posle odjave nema obnove');
  });
}
