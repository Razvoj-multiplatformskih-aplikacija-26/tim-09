import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mobile/app.dart';
import 'package:mobile/dependencies.dart';
import 'package:ui/ui.dart';
import 'package:use_cases/use_cases.dart';

/// Ponedeljak u 9:00, da seed i pravila uvek daju iste rezultate.
final testNow = DateTime(2026, 10, 26, 9);

const washerUser = User(id: UserId('u-washer-1'), username: 'nikola', role: Role.washer, washerId: WasherId('w-1'));

Future<AppDependencies> pumpApp(
  WidgetTester tester, {
  Size size = const Size(1080, 2400),
  Duration latency = Duration.zero,
  bool settle = true,
  User? signedIn = AppDependencies.currentClient,
}) async {
  await initializeDateFormatting(serbianLatin);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final dependencies = AppDependencies.fake(clock: FixedClock(testNow), latency: latency, signedIn: signedIn);
  await tester.pumpWidget(CarWashApp(dependencies: dependencies));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return dependencies;
}

Future<void> signIn(WidgetTester tester, String username, {String password = 'DemoPass123!'}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Korisničko ime'), username);
  await tester.enterText(find.widgetWithText(TextFormField, 'Lozinka'), password);
  await tester.tap(find.widgetWithText(FilledButton, 'Prijavi se'));
  await tester.pumpAndSettle();
}
