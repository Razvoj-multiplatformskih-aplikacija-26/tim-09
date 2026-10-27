import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  group('stanja', () {
    test('dozvoljeno je tačno 7 prelaza od 25', () {
      final statuses = <WashStatus>[
        const Submitted(),
        accepted(),
        InProgress(arrivedAt: now),
        Completed(finishedAt: now),
        Cancelled(reason: '', cancelledBy: client.id, at: now),
      ];
      final allowed = [
        for (final from in statuses)
          for (final to in statuses)
            if (canTransition(from, to)) (from, to),
      ];
      expect(allowed, hasLength(7));
    });
  });

  group('R4 · otkazivanje', () {
    test('prijavljen zahtev klijent otkazuje uvek', () {
      final request = requestAt(now.add(const Duration(minutes: 10)));
      expect(cancelRequest(request, by: client, now: now).isSuccess, isTrue);
    });

    test('prihvaćen: tačno 1 h pre termina prolazi, minut kasnije pada', () {
      final start = now.add(const Duration(hours: 1));
      final request = requestAt(start, status: accepted());
      expect(cancelRequest(request, by: client, now: now).isSuccess, isTrue);
      expect(
        cancelRequest(request, by: client, now: now.add(const Duration(minutes: 1))).errorOrNull,
        isA<CancellationTooLate>(),
      );
    });

    test('perač kasni više od 30 min: klijent ipak može da otkaže', () {
      final request = requestAt(now.subtract(const Duration(minutes: 31)), status: accepted());
      expect(isWasherLate(request, now: now), isTrue);
      expect(cancelRequest(request, by: client, now: now).isSuccess, isTrue);
    });

    test('tuđi zahtev ili zahtev u toku klijent ne može da otkaže', () {
      expect(cancelRequest(requestAt(now), by: otherClient, now: now).errorOrNull, isA<NotAllowed>());
      final running = requestAt(now, status: InProgress(arrivedAt: now));
      expect(cancelRequest(running, by: client, now: now).errorOrNull, isA<NotAllowed>());
    });

    test('završen zahtev ne može da se otkaže', () {
      final done = requestAt(now, status: Completed(finishedAt: now));
      expect(cancelRequest(done, by: dispatcher, now: now).errorOrNull, isA<InvalidTransition>());
    });
  });

  group('R6 · najviše 3 zahteva na čekanju', () {
    test('dva na čekanju i jedan u toku: može još jedan', () {
      final requests = [
        requestAt(now),
        requestAt(now, status: accepted()),
        requestAt(now, status: InProgress(arrivedAt: now)),
      ];
      expect(canSubmit(client.id, requests), isTrue);
    });

    test('tri na čekanju: ne može', () {
      final requests = [requestAt(now), requestAt(now), requestAt(now, status: accepted())];
      expect(canSubmit(client.id, requests), isFalse);
    });

    test('tuđi zahtevi se ne broje', () {
      final requests = [for (var i = 0; i < 3; i++) requestAt(now, clientId: otherClient.id)];
      expect(canSubmit(client.id, requests), isTrue);
    });
  });
}
