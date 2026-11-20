import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:backoffice/app.dart';
import 'package:backoffice/dependencies.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ui/ui.dart';
import 'package:use_cases/testing.dart';
import 'package:use_cases/use_cases.dart';

import 'support.dart';

Future<void> chooseFilter(WidgetTester tester, String label) async {
  await tapAndSettle(tester, find.byTooltip('Filter stanja'));
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void completeOtherSubmitted(BackofficeDependencies dependencies, {required String keep}) {
  final repository = dependencies.fakeRepository!;
  for (final request in repository.all.where((r) => r.status is Submitted && r.id.value != keep)) {
    repository.replace(request.copyWith(status: Completed(finishedAt: testNow)));
  }
}

void main() {
  group('ispravka 1: „Sva stanja“ uklanja filter', () {
    testWidgets('„U toku“ pa „Sva stanja“ ponovo prikazuje sva stanja', (tester) async {
      await pumpApp(tester);
      await chooseFilter(tester, 'U toku');
      expect(find.text('Čekaju perača'), findsNothing);
      expect(find.textContaining('BG 4410-TT'), findsOneWidget);

      await chooseFilter(tester, 'Sva stanja');
      expect(find.text('Čekaju perača'), findsOneWidget);
      expect(find.text('Prethodni'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Sva stanja'), findsOneWidget);
    });

    testWidgets('zatvaranje menija bez izbora čuva filter', (tester) async {
      await pumpApp(tester);
      await chooseFilter(tester, 'U toku');
      await tapAndSettle(tester, find.byTooltip('Filter stanja'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'U toku'), findsOneWidget);
      expect(find.text('Čekaju perača'), findsNothing);

      await tapAndSettle(tester, find.byTooltip('Filter stanja'));
      await tester.tapAt(const Offset(20, 900));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'U toku'), findsOneWidget);
      expect(find.text('Čekaju perača'), findsNothing);
    });

    testWidgets('„Prikaži sve“ iz praznog prikaza vraća i oznaku menija', (tester) async {
      final dependencies = await pumpApp(tester);
      final repository = dependencies.fakeRepository!;
      for (final request in repository.all.where((r) => r.status is InProgress)) {
        repository.replace(request.copyWith(status: Completed(finishedAt: testNow)));
      }
      await chooseFilter(tester, 'U toku');
      await tapAndSettle(tester, find.text('Prikaži sve'));
      expect(find.text('Čekaju perača'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Sva stanja'), findsOneWidget);
    });

    testWidgets('mrežni sloj posle resetovanja šalje listu bez status parametra', (tester) async {
      await initializeDateFormatting(serbianLatin);
      tester.view.physicalSize = wide;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final lists = <Uri>[];
      final client = MockClient((request) async {
        http.Response json(Object body) =>
            http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        return switch (request.url.path) {
          '/auth/me' => json({
            'user': {'id': 'u-dispatcher', 'username': 'dispecer', 'role': 'dispatcher'},
            'expiresAt': '2026-11-20T10:00:00Z',
          }),
          '/washers' => json({'items': <Object?>[]}),
          _ => () {
            lists.add(request.url);
            return json({
              'items': [
                {
                  'id': 'wr-1',
                  'clientId': 'u-client',
                  'vehicle': {'type': 'sedan', 'plate': 'BG 123-AB'},
                  'tier': 'economy',
                  'address': {'text': 'Knez Mihailova 6'},
                  'slot': {'start': '2026-11-21T09:00:00Z', 'durationMinutes': 45},
                  'note': null,
                  'createdAt': '2026-11-20T09:00:00Z',
                  'priceRsd': 1400,
                  'currency': 'RSD',
                  'status': {'type': 'in_progress', 'washerId': 'w-1', 'arrivedAt': '2026-11-20T09:00:00Z'},
                },
              ],
              'total': 1,
              'limit': 50,
              'offset': 0,
            });
          }(),
        };
      });
      final api = CarWashApi(
        baseUrl: Uri.parse('http://localhost:8080'),
        client: client,
        session: SessionController(transport: SessionTransport.bearer),
      );
      final dependencies = BackofficeDependencies(
        clock: FixedClock(testNow),
        auth: HttpAuthRepository(
          api: api,
          application: ClientApplication.backoffice,
          storage: InMemorySessionStorage('token'),
        ),
        requests: HttpWashRequestRepository(api),
        washers: HttpWasherRepository(api),
      );
      await tester.pumpWidget(BackofficeApp(dependencies: dependencies));
      await tester.pumpAndSettle();
      await chooseFilter(tester, 'U toku');
      expect(lists.last.queryParameters['status'], 'in_progress');
      await chooseFilter(tester, 'Sva stanja');
      expect(lists.last.queryParameters, {'scope': 'all', 'limit': '50', 'offset': '0'});
    });
  });

  group('ispravka 3: detalj na uskom ekranu zadržava radnje kad lista postane prazna', () {
    testWidgets('dodela jedinog prijavljenog: obe radnje ostaju, „Vrati u red“ stvarno radi', (tester) async {
      final dependencies = await pumpApp(tester, size: narrow);
      completeOtherSubmitted(dependencies, keep: 'wr-104');
      await chooseFilter(tester, 'Prijavljen');
      await tapAndSettle(tester, tileOf('NS 882-PT'));
      await tapAndSettle(tester, find.text('Dodeli perača'));
      await tapAndSettle(tester, find.text('Stefan Marković'));

      final repository = dependencies.fakeRepository!;
      final assigned = repository.all.firstWhere((r) => r.id.value == 'wr-104');
      expect(assigned.status, isA<Accepted>());
      expect(find.text('Prihvaćen'), findsOneWidget);
      expect(find.text('Vrati u red'), findsOneWidget);
      expect(find.text('Otkaži zahtev'), findsOneWidget);

      await tapAndSettle(tester, find.text('Vrati u red'));
      expect(find.text('Zahtev je vraćen u red.'), findsOneWidget);
      expect(repository.all.firstWhere((r) => r.id.value == 'wr-104').status, isA<Submitted>());
      expect(find.text('Dodeli perača'), findsOneWidget);
      await tapAndSettle(tester, find.text('Dodeli perača'));
      expect(find.text('Slobodan'), findsNWidgets(2));
      await tapAndSettle(tester, find.text('Stefan Marković'));

      await tapAndSettle(tester, find.byType(BackButton));
      expect(find.text('Nema zahteva u stanju „Prijavljen“.'), findsOneWidget);
    });

    testWidgets('otkazivanje posle dodele: dijalog, stvarna promena i nestanak radnji', (tester) async {
      final dependencies = await pumpApp(tester, size: narrow);
      completeOtherSubmitted(dependencies, keep: 'wr-104');
      await chooseFilter(tester, 'Prijavljen');
      await tapAndSettle(tester, tileOf('NS 882-PT'));
      await tapAndSettle(tester, find.text('Dodeli perača'));
      await tapAndSettle(tester, find.text('Stefan Marković'));
      await tapAndSettle(tester, find.text('Otkaži zahtev'));
      expect(find.text('Otkazati zahtev?'), findsOneWidget);
      await tapAndSettle(tester, find.text('Otkaži zahtev').last);
      expect(find.text('Zahtev je otkazan.'), findsOneWidget);
      expect(dependencies.fakeRepository!.all.firstWhere((r) => r.id.value == 'wr-104').status, isA<Cancelled>());
      expect(find.text('Otkazan'), findsOneWidget);
      expect(find.text('Vrati u red'), findsNothing);
      expect(find.text('Otkaži zahtev'), findsNothing);
    });

    testWidgets('obrnuto: jedini prihvaćeni se vraća u red, pa se sa prazne table ponovo dodeljuje', (tester) async {
      final dependencies = await pumpApp(tester, size: narrow);
      await chooseFilter(tester, 'Prihvaćen');
      await tapAndSettle(tester, tileOf('BG 909-ZR'));
      await tapAndSettle(tester, find.text('Vrati u red'));
      expect(find.text('Prijavljen'), findsOneWidget);
      expect(find.text('Dodeli perača'), findsOneWidget);

      await tapAndSettle(tester, find.text('Dodeli perača'));
      expect(find.text('Nikola Petrović'), findsOneWidget);
      expect(find.text('Slobodan'), findsNWidgets(3));
      await tapAndSettle(tester, find.text('Nikola Petrović'));
      expect(find.text('Zahtev je dodeljen peraču.'), findsOneWidget);
      final request = dependencies.fakeRepository!.all.firstWhere((r) => r.id.value == 'wr-105');
      expect(request.status, isA<Accepted>().having((s) => s.washerId, 'washer', const WasherId('w-1')));
      expect(find.text('Vrati u red'), findsOneWidget);
    });

    testWidgets('neuspela radnja na praznoj tabli javlja razlog, uklanja busy i dopušta nastavak', (tester) async {
      final dependencies = await pumpApp(tester, size: narrow);
      await chooseFilter(tester, 'Prihvaćen');
      await tapAndSettle(tester, tileOf('BG 909-ZR'));
      await tapAndSettle(tester, find.text('Vrati u red'));
      dependencies.fakeRepository!.failingRequests = 1;
      await tapAndSettle(tester, find.text('Dodeli perača'));
      await tapAndSettle(tester, find.text('Nikola Petrović'));
      expect(find.text('Radnja nije uspela. Pokušajte ponovo.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tapAndSettle(tester, find.text('Dodeli perača'));
      await tapAndSettle(tester, find.text('Nikola Petrović'));
      expect(find.text('Zahtev je dodeljen peraču.'), findsOneWidget);
    });
  });

  testWidgets('kombinacija: filter, radnja koja isprazni listu, povratak i osvežavanje na širokom ekranu', (
    tester,
  ) async {
    final dependencies = await pumpApp(tester);
    completeOtherSubmitted(dependencies, keep: 'wr-104');
    await chooseFilter(tester, 'Prijavljen');
    await tapAndSettle(tester, tileOf('NS 882-PT'));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Stefan Marković'));
    expect(find.text('Nema zahteva u stanju „Prijavljen“.'), findsOneWidget);
    await chooseFilter(tester, 'Sva stanja');
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(find.textContaining('Perač: Stefan Marković'), findsOneWidget);
  });
}
