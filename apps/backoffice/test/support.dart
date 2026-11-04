import 'package:backoffice/app.dart';
import 'package:backoffice/dependencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ui/ui.dart';
import 'package:use_cases/use_cases.dart';

/// Ponedeljak u 9:00, da seed i pravila uvek daju iste rezultate.
final testNow = DateTime(2026, 10, 26, 9);

const wide = Size(1600, 1000);
const narrow = Size(600, 1000);

Future<BackofficeDependencies> pumpApp(
  WidgetTester tester, {
  Size size = wide,
  Duration latency = Duration.zero,
}) async {
  await initializeDateFormatting(serbianLatin);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final dependencies = BackofficeDependencies.fake(clock: FixedClock(testNow), latency: latency);
  await tester.pumpWidget(BackofficeApp(dependencies: dependencies));
  await tester.pumpAndSettle();
  return dependencies;
}

/// Red u listi po registarskoj oznaci; prvi pogodak je onaj najviše u listi.
Finder tileOf(String plate) => find.textContaining(plate).first;

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
