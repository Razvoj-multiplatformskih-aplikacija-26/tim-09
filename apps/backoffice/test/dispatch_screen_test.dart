import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import 'support.dart';

void main() {
  group('stanja ekrana', () {
    testWidgets('dok se učitava prikazuje kostur, pa listu u tri odeljka', (tester) async {
      await pumpApp(tester, latency: const Duration(milliseconds: 700));
      // pumpAndSettle u pumpApp prolazi kroz kašnjenje, pa se kostur proverava na novom učitavanju.
      await tester.tap(find.byTooltip('Osveži (F5)'));
      await tester.pump();
      expect(find.byType(ListSkeleton), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(ListSkeleton), findsNothing);
      expect(find.text('Čekaju perača'), findsOneWidget);
      expect(find.text('Aktivni'), findsOneWidget);
      expect(find.text('Prethodni'), findsOneWidget);
      expect(find.text('Izaberite zahtev iz liste.'), findsOneWidget);
    });

    testWidgets('statusi su na srpskom, ne imena klasa', (tester) async {
      await pumpApp(tester);
      expect(find.text('Prijavljen'), findsNWidgets(4));
      expect(find.text('Prihvaćen'), findsOneWidget);
      expect(find.text('U toku'), findsOneWidget);
      expect(find.text('Završen'), findsOneWidget);
      expect(find.text('Otkazan'), findsNWidgets(2));
      expect(find.textContaining('Submitted'), findsNothing);
      expect(find.textContaining('Perač: Nikola Petrović'), findsOneWidget);
    });

    testWidgets('greška pa „Pokušaj ponovo“ vraća podatke', (tester) async {
      final dependencies = await pumpApp(tester);
      await tapAndSettle(tester, find.byTooltip('Simulacija'));
      await tapAndSettle(tester, find.text('Simuliraj grešku'));
      expect(find.text('Podaci trenutno nisu dostupni.'), findsOneWidget);
      expect(dependencies.fakeRepository!.failingRequests, 0);

      await tapAndSettle(tester, find.text('Pokušaj ponovo'));
      expect(find.text('Čekaju perača'), findsOneWidget);
    });

    testWidgets('prazan odgovor prikazuje prazan ekran', (tester) async {
      await pumpApp(tester);
      await tapAndSettle(tester, find.byTooltip('Simulacija'));
      await tapAndSettle(tester, find.text('Simuliraj prazan odgovor'));
      expect(find.text('Nema zahteva u sistemu.'), findsOneWidget);
    });
  });

  group('širok ekran', () {
    testWidgets('izbor zahteva prikazuje detalje pored liste', (tester) async {
      await pumpApp(tester);
      await tapAndSettle(tester, tileOf('NI 789-EF'));
      expect(find.text('Zahtev wr-103'), findsOneWidget);
      expect(find.text('Kombi je visok 2,4 m.'), findsOneWidget);
      expect(find.text('Obrenovićeva 42, Niš'), findsOneWidget);
      expect(find.text('Dodeli perača'), findsOneWidget);
    });

    testWidgets('dodela slobodnom peraču: zauzeti se ne nude, posle dodele zahtev je prihvaćen', (tester) async {
      await pumpApp(tester);
      await tapAndSettle(tester, tileOf('NS 882-PT'));
      await tapAndSettle(tester, find.text('Dodeli perača'));
      expect(find.text('Ima aktivan posao'), findsNWidgets(2));
      expect(find.text('Slobodan'), findsNWidgets(2));

      // Zauzet perač je onemogućen: dodir ne zatvara dijalog.
      await tapAndSettle(tester, find.text('Nikola Petrović'));
      expect(find.text('Ima aktivan posao'), findsNWidgets(2));

      await tapAndSettle(tester, find.text('Stefan Marković'));
      expect(find.text('Zahtev je dodeljen peraču.'), findsOneWidget);
      expect(find.text('Zahtev wr-104'), findsOneWidget);
      expect(find.text('Stefan Marković'), findsOneWidget);
      expect(find.text('Vrati u red'), findsOneWidget);
      expect(find.text('Dodeli perača'), findsNothing);
      expect(find.text('Prihvaćen'), findsNWidgets(3));
    });

    testWidgets('perača je u međuvremenu zauzeo drugi dispečer → domen odbija dodelu', (tester) async {
      final dependencies = await pumpApp(tester);
      final repository = dependencies.fakeRepository!;
      await tester.runAsync(() async {
        final other = (await repository.find(const WashRequestId('wr-102')))!;
        await repository.save(
          other.copyWith(
            status: Accepted(washerId: const WasherId('w-3'), acceptedBy: const UserId('u-other'), at: testNow),
          ),
        );
      });

      await tapAndSettle(tester, tileOf('NS 882-PT'));
      await tapAndSettle(tester, find.text('Dodeli perača'));
      await tapAndSettle(tester, find.text('Stefan Marković'));
      expect(find.text('Perač je trenutno zauzet drugim poslom.'), findsOneWidget);
      expect(find.text('Dodeli perača'), findsOneWidget);
    });

    testWidgets('vraćanje u red oslobađa perača', (tester) async {
      await pumpApp(tester);
      await tapAndSettle(tester, tileOf('BG 909-ZR'));
      await tapAndSettle(tester, find.text('Vrati u red'));
      expect(find.text('Zahtev je vraćen u red.'), findsOneWidget);
      expect(find.text('Dodeli perača'), findsOneWidget);
      expect(find.text('Prijavljen'), findsNWidgets(6));

      await tapAndSettle(tester, find.text('Dodeli perača'));
      expect(find.text('Ima aktivan posao'), findsOneWidget);
    });

    testWidgets('otkazivanje traži potvrdu i čuva razlog', (tester) async {
      await pumpApp(tester);
      await tapAndSettle(tester, tileOf('NS 882-PT'));
      await tapAndSettle(tester, find.text('Otkaži zahtev'));
      expect(find.text('Otkazati zahtev?'), findsOneWidget);

      await tapAndSettle(tester, find.text('Odustani'));
      expect(find.text('Dodeli perača'), findsOneWidget);

      await tapAndSettle(tester, find.text('Otkaži zahtev'));
      await tapAndSettle(tester, find.text('Otkaži zahtev').last);
      expect(find.text('Zahtev je otkazan.'), findsOneWidget);
      expect(find.text('Otkazao dispečer.'), findsOneWidget);
      expect(find.text('Dodeli perača'), findsNothing);
      expect(find.text('Otkaži zahtev'), findsNothing);
    });

    testWidgets('dispečer može da otkaže i pranje koje je u toku', (tester) async {
      await pumpApp(tester);
      await tapAndSettle(tester, tileOf('BG 4410-TT'));
      expect(find.text('Jovan Ilić'), findsOneWidget);
      expect(find.text('Vrati u red'), findsNothing);
      await tapAndSettle(tester, find.text('Otkaži zahtev'));
      await tapAndSettle(tester, find.text('Otkaži zahtev').last);
      expect(find.text('Zahtev je otkazan.'), findsOneWidget);
    });

    testWidgets('završen i otkazan zahtev nemaju radnje', (tester) async {
      await pumpApp(tester);
      for (final plate in ['BG 123-AB', 'NS 4521-KM']) {
        await tapAndSettle(tester, find.textContaining(plate).last);
        expect(find.text('Dodeli perača'), findsNothing);
        expect(find.text('Vrati u red'), findsNothing);
        expect(find.text('Otkaži zahtev'), findsNothing);
      }
      expect(find.text('Otkazao klijent.'), findsOneWidget);
    });

    testWidgets('tastatura: strelice biraju, Esc poništava, A dodeljuje, F5 čuva izbor', (tester) async {
      await pumpApp(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(find.text('Zahtev wr-101'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(find.text('Zahtev wr-102'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(find.text('Zahtev wr-101'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.pumpAndSettle();
      expect(find.text('Zahtev wr-101'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pumpAndSettle();
      expect(find.text('Ima aktivan posao'), findsNWidgets(2));
      await tapAndSettle(tester, find.text('Luka Đorđević'));
      expect(find.text('Zahtev je dodeljen peraču.'), findsOneWidget);

      // Fokus se posle dijaloga vraća, pa prečice i dalje rade.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Izaberite zahtev iz liste.'), findsOneWidget);
    });

    testWidgets('A ne radi ništa za zahtev koji nije prijavljen', (tester) async {
      await pumpApp(tester);
      await tapAndSettle(tester, tileOf('BG 909-ZR'));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pumpAndSettle();
      expect(find.text('Ima aktivan posao'), findsNothing);
    });
  });

  group('uzak ekran', () {
    testWidgets('dodir otvara detalje, dodela radi i detalji pokazuju novo stanje', (tester) async {
      await pumpApp(tester, size: narrow);
      expect(find.text('Izaberite zahtev iz liste.'), findsNothing);

      await tapAndSettle(tester, tileOf('NS 882-PT'));
      expect(find.text('Zahtev wr-104'), findsWidgets);
      await tapAndSettle(tester, find.text('Dodeli perača'));
      await tapAndSettle(tester, find.text('Stefan Marković'));

      expect(tester.takeException(), isNull);
      expect(find.text('Zahtev je dodeljen peraču.'), findsOneWidget);
      expect(find.text('Vrati u red'), findsOneWidget);
      expect(find.text('Dodeli perača'), findsNothing);

      await tapAndSettle(tester, find.byType(BackButton));
      expect(find.text('Dispečerska tabla'), findsOneWidget);
      expect(find.textContaining('Perač: Stefan Marković'), findsOneWidget);
    });

    testWidgets('otkazivanje sa ekrana detalja', (tester) async {
      await pumpApp(tester, size: narrow);
      await tapAndSettle(tester, tileOf('NS 882-PT'));
      await tapAndSettle(tester, find.text('Otkaži zahtev'));
      await tapAndSettle(tester, find.text('Otkaži zahtev').last);
      expect(tester.takeException(), isNull);
      expect(find.text('Zahtev je otkazan.'), findsOneWidget);
      expect(find.text('Otkazan'), findsOneWidget);
    });
  });

  for (final size in const [Size(360, 640), Size(899, 700), Size(900, 700), Size(1280, 720), Size(1920, 1080)]) {
    testWidgets('raspored bez prelivanja na ${size.width.toInt()}×${size.height.toInt()}', (tester) async {
      await pumpApp(tester, size: size);
      await tapAndSettle(tester, tileOf('NI 789-EF'));
      expect(find.text('Zahtev wr-103'), findsWidgets);
      await tapAndSettle(tester, find.text('Dodeli perača'));
      expect(find.text('Luka Đorđević'), findsOneWidget);
    });
  }
}
