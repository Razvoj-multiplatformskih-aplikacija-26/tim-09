import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  testWidgets('klijent ne ulazi u backoffice, dispečer ulazi', (tester) async {
    await pumpApp(tester, signedIn: null);
    expect(find.text('CarWash & Go · prijava za dispečere'), findsOneWidget);
    await signIn(tester, 'marko');
    expect(find.text('Backoffice je namenjen dispečerima.'), findsOneWidget);
    expect(find.text('Čekaju perača'), findsNothing);

    await signIn(tester, 'dispecer');
    expect(find.text('Čekaju perača'), findsOneWidget);
  });

  testWidgets('odjava vraća na prijavu i uklanja tablu', (tester) async {
    final dependencies = await pumpApp(tester);
    await tapAndSettle(tester, find.byIcon(Icons.logout));
    expect(find.text('CarWash & Go · prijava za dispečere'), findsOneWidget);
    expect(find.text('Čekaju perača'), findsNothing);
    expect(dependencies.fakeAuth!.logouts, 1);
  });

  testWidgets('istek sesije vraća na prijavu uz poruku', (tester) async {
    final dependencies = await pumpApp(tester);
    dependencies.fakeAuth!.expire();
    await tester.pumpAndSettle();
    expect(find.text('Prijava je istekla. Prijavite se ponovo.'), findsOneWidget);
  });

  testWidgets('filter stanja ide kroz Bloc, prazan rezultat nudi povratak na sve', (tester) async {
    final dependencies = await pumpApp(tester);
    await tapAndSettle(tester, find.byTooltip('Filter stanja'));
    await tapAndSettle(tester, find.text('U toku').last);
    expect(find.textContaining('BG 4410-TT'), findsOneWidget);
    expect(find.text('Čekaju perača'), findsNothing);
    expect(find.text('1–1 od 1'), findsOneWidget);

    for (final request in dependencies.fakeRepository!.all.where((r) => r.status is InProgress)) {
      dependencies.fakeRepository!.replace(request.copyWith(status: Completed(finishedAt: testNow)));
    }
    await tapAndSettle(tester, find.byTooltip('Osveži (F5)'));
    expect(find.text('Nema zahteva u stanju „U toku“.'), findsOneWidget);
    await tapAndSettle(tester, find.text('Prikaži sve'));
    expect(find.text('Čekaju perača'), findsOneWidget);
  });

  testWidgets('posle odbijene dodele perači se osvežavaju sa servera', (tester) async {
    final dependencies = await pumpApp(tester);
    final repository = dependencies.fakeRepository!;
    final other = repository.all.firstWhere((r) => r.id == const WashRequestId('wr-102'));
    repository.replace(
      other.copyWith(
        status: Accepted(washerId: const WasherId('w-3'), acceptedBy: const UserId('u-other'), at: testNow),
      ),
    );
    await tapAndSettle(tester, tileOf('NS 882-PT'));
    await tapAndSettle(tester, find.text('Dodeli perača'));
    expect(find.text('Slobodan'), findsNWidgets(2));
    await tapAndSettle(tester, find.text('Stefan Marković'));
    expect(find.text('Perač je trenutno zauzet drugim poslom.'), findsOneWidget);

    await tapAndSettle(tester, find.text('Dodeli perača'));
    expect(find.text('Slobodan'), findsOneWidget);
    expect(find.text('Ima aktivan posao'), findsNWidgets(3));
  });

  testWidgets('ukupan broj dolazi sa servera, ne iz broja redova', (tester) async {
    await pumpApp(tester);
    await tester.scrollUntilVisible(find.text('1–9 od 9'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('1–9 od 9'), findsOneWidget);
  });
}
