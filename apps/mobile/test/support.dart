import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mobile/app.dart';
import 'package:mobile/dependencies.dart';
import 'package:ui/ui.dart';
import 'package:use_cases/use_cases.dart';

/// Ponedeljak u 9:00, da seed i pravila uvek daju iste rezultate.
final testNow = DateTime(2026, 10, 26, 9);

Future<AppDependencies> pumpApp(
  WidgetTester tester, {
  Size size = const Size(1080, 2400),
  Duration latency = Duration.zero,
  bool settle = true,
}) async {
  await initializeDateFormatting(serbianLatin);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final dependencies = AppDependencies.fake(clock: FixedClock(testNow), latency: latency);
  await tester.pumpWidget(CarWashApp(dependencies: dependencies));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return dependencies;
}
