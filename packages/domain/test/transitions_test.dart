import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  group('stanja', () {
    test('dozvoljeno je tačno 7 prelaza od 25', () {
      final statuses = <WashStatus>[
        const Submitted(),
        accepted(),
        InProgress(washerId: const WasherId('w-1'), arrivedAt: now),
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
      final running = requestAt(
        now,
        status: InProgress(washerId: const WasherId('w-1'), arrivedAt: now),
      );
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
        requestAt(
          now,
          status: InProgress(washerId: const WasherId('w-1'), arrivedAt: now),
        ),
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

  group('R3 · perač ima najviše jedan aktivan posao', () {
    const washer = WasherId('w-1');
    const otherWasher = WasherId('w-2');

    test('slobodan perač dobija prijavljen zahtev', () {
      final result = acceptRequest(requestAt(now), washer: washer, by: dispatcher, now: now, all: []);
      expect(result.valueOrNull?.status, Accepted(washerId: washer, acceptedBy: dispatcher.id, at: now));
    });

    test('perač sa prihvaćenim ili započetim poslom je zauzet', () {
      for (final status in [accepted(), inProgress()]) {
        final all = [requestAt(now, status: status)];
        expect(
          acceptRequest(requestAt(now), washer: washer, by: dispatcher, now: now, all: all).errorOrNull,
          isA<WasherBusy>(),
        );
      }
    });

    test('završeni i otkazani poslovi i poslovi drugih perača se ne broje', () {
      final all = [
        requestAt(now, status: Completed(finishedAt: now)),
        requestAt(
          now,
          status: Cancelled(reason: '', cancelledBy: dispatcher.id, at: now),
        ),
        requestAt(
          now,
          status: Accepted(washerId: otherWasher, acceptedBy: dispatcher.id, at: now),
        ),
      ];
      expect(acceptRequest(requestAt(now), washer: washer, by: dispatcher, now: now, all: all).isSuccess, isTrue);
    });

    test('klijent ne dodeljuje perača, a prihvaćen zahtev se ne dodeljuje ponovo', () {
      expect(
        acceptRequest(requestAt(now), washer: washer, by: client, now: now, all: []).errorOrNull,
        isA<NotAllowed>(),
      );
      final taken = requestAt(now, status: accepted());
      expect(
        acceptRequest(taken, washer: otherWasher, by: dispatcher, now: now, all: []).errorOrNull,
        isA<InvalidTransition>(),
      );
    });
  });

  group('vraćanje u red', () {
    test('prihvaćen zahtev se vraća u Prijavljen', () {
      final result = releaseRequest(requestAt(now, status: accepted()), by: dispatcher);
      expect(result.valueOrNull?.status, const Submitted());
    });

    test('samo prihvaćen zahtev, i samo dispečer', () {
      expect(releaseRequest(requestAt(now), by: dispatcher).errorOrNull, isA<InvalidTransition>());
      expect(releaseRequest(requestAt(now, status: accepted()), by: client).errorOrNull, isA<NotAllowed>());
    });
  });
}
