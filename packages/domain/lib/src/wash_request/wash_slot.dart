import 'package:meta/meta.dart';

import '../errors.dart';
import '../result.dart';

/// R3 · Termin pranja: najranije [minNotice] od sada, najkasnije [maxAdvance] unapred,
/// počinje na pun sat ili pola sata, između [openingHour] i [closingHour] h,
/// i pranje mora da se završi do [closingHour] h.
@immutable
final class WashSlot {
  const WashSlot._(this.start, this.duration);

  /// Termin koji je već sačuvan (npr. u prošlosti), pa se pravila ne proveravaju ponovo.
  const WashSlot.existing(this.start, this.duration);

  static const minNotice = Duration(hours: 1);
  static const maxAdvance = Duration(days: 7);
  static const openingHour = 8;
  static const closingHour = 20;

  final DateTime start;
  final Duration duration;

  DateTime get end => start.add(duration);

  static Result<WashSlot> parse(DateTime start, {required Duration duration, required DateTime now}) {
    if (start.isBefore(now.add(minNotice))) return const Failure(SlotTooSoon());
    if (start.isAfter(now.add(maxAdvance))) return const Failure(SlotTooFar());
    if (start.minute % 30 != 0 || start.second != 0) return const Failure(SlotNotOnHalfHour());
    final closing = DateTime(start.year, start.month, start.day, closingHour);
    if (start.hour < openingHour || start.add(duration).isAfter(closing)) {
      return const Failure(OutsideWorkingHours());
    }
    return Success(WashSlot._(start, duration));
  }

  @override
  bool operator ==(Object other) => other is WashSlot && other.start == start && other.duration == duration;

  @override
  int get hashCode => Object.hash(start, duration);

  @override
  String toString() => 'WashSlot(${start.toIso8601String()}, ${duration.inMinutes} min)';
}
