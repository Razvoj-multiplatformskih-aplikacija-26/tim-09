abstract interface class Clock {
  DateTime now();
}

/// Jedino mesto u sistemu koje čita sistemski sat.
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

final class FixedClock implements Clock {
  const FixedClock(this.instant);

  final DateTime instant;

  @override
  DateTime now() => instant;
}
