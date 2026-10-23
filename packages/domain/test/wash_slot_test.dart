import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  const wash = Duration(minutes: 45);

  Result<WashSlot> slotAt(DateTime start) => WashSlot.parse(start, duration: wash, now: now);

  group('R3 · termin', () {
    test('tačno 1 h od sada prolazi, pola sata ranije pada', () {
      expect(slotAt(now.add(const Duration(hours: 1))).isSuccess, isTrue);
      expect(slotAt(now.add(const Duration(minutes: 30))).errorOrNull, isA<SlotTooSoon>());
    });

    test('više od 7 dana unapred pada', () {
      expect(slotAt(DateTime(2026, 11, 2, 10)).errorOrNull, isA<SlotTooFar>());
    });

    test('termin počinje na :00 ili :30', () {
      expect(slotAt(DateTime(2026, 10, 27, 10, 30)).isSuccess, isTrue);
      expect(slotAt(DateTime(2026, 10, 27, 10, 15)).errorOrNull, isA<SlotNotOnHalfHour>());
    });

    test('pre 8 h i završetak posle 20 h padaju', () {
      expect(slotAt(DateTime(2026, 10, 27, 7, 30)).errorOrNull, isA<OutsideWorkingHours>());
      expect(slotAt(DateTime(2026, 10, 27, 19)).isSuccess, isTrue); // 19:00 + 45 min = 19:45
      expect(slotAt(DateTime(2026, 10, 27, 19, 30)).errorOrNull, isA<OutsideWorkingHours>());
    });
  });
}
