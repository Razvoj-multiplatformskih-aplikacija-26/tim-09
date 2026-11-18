import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  test('zimski termin u UTC proverava se prema beogradskom radnom vremenu', () {
    final now = DateTime.utc(2026, 11, 18, 5);
    expect(
      WashSlot.parse(DateTime.utc(2026, 11, 18, 7), duration: const Duration(minutes: 45), now: now).isSuccess,
      isTrue,
    );
    expect(
      WashSlot.parse(DateTime.utc(2026, 11, 18, 6, 30), duration: const Duration(minutes: 45), now: now).errorOrNull,
      isA<OutsideWorkingHours>(),
    );
  });

  test('letnji termin i završetak do 20 koriste letnje računanje vremena', () {
    final now = DateTime.utc(2026, 7, 1, 4);
    expect(
      WashSlot.parse(DateTime.utc(2026, 7, 1, 6), duration: const Duration(minutes: 45), now: now).isSuccess,
      isTrue,
    );
    expect(
      WashSlot.parse(DateTime.utc(2026, 7, 1, 17, 30), duration: const Duration(minutes: 45), now: now).errorOrNull,
      isA<OutsideWorkingHours>(),
    );
  });

  test('deo sekunde nije termin na pun sat ili pola sata', () {
    expect(
      WashSlot.parse(
        DateTime.utc(2026, 11, 19, 9, 0, 0, 1),
        duration: const Duration(minutes: 45),
        now: DateTime.utc(2026, 11, 18),
      ).errorOrNull,
      isA<SlotNotOnHalfHour>(),
    );
  });
}
