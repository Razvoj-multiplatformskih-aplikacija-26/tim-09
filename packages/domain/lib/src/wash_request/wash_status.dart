import 'package:meta/meta.dart';

import '../identifiers.dart';

/// Stanja zahteva za pranje (zahtev 2).
sealed class WashStatus {
  const WashStatus();

  bool get isActive => switch (this) {
    Submitted() || Accepted() || InProgress() => true,
    Completed() || Cancelled() => false,
  };

  bool get isFinal => !isActive;
}

/// Prijavljen: klijent je poslao zahtev, čeka perača.
final class Submitted extends WashStatus {
  const Submitted();

  @override
  bool operator ==(Object other) => other is Submitted;

  @override
  int get hashCode => (Submitted).hashCode;

  @override
  String toString() => 'Submitted';
}

/// Prihvaćen: dispečer je dodelio perača.
@immutable
final class Accepted extends WashStatus {
  const Accepted({required this.washerId, required this.acceptedBy, required this.at});

  final WasherId washerId;
  final UserId acceptedBy;
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      other is Accepted && other.washerId == washerId && other.acceptedBy == acceptedBy && other.at == at;

  @override
  int get hashCode => Object.hash(washerId, acceptedBy, at);

  @override
  String toString() => 'Accepted($washerId at $at)';
}

/// U toku: perač je stigao i pere vozilo.
@immutable
final class InProgress extends WashStatus {
  const InProgress({required this.arrivedAt});

  final DateTime arrivedAt;

  @override
  bool operator ==(Object other) => other is InProgress && other.arrivedAt == arrivedAt;

  @override
  int get hashCode => arrivedAt.hashCode;

  @override
  String toString() => 'InProgress(since $arrivedAt)';
}

/// Završen: pranje je gotovo.
@immutable
final class Completed extends WashStatus {
  const Completed({required this.finishedAt});

  final DateTime finishedAt;

  @override
  bool operator ==(Object other) => other is Completed && other.finishedAt == finishedAt;

  @override
  int get hashCode => finishedAt.hashCode;

  @override
  String toString() => 'Completed(at $finishedAt)';
}

/// Otkazan: otkazao klijent ili dispečer.
@immutable
final class Cancelled extends WashStatus {
  const Cancelled({required this.reason, required this.cancelledBy, required this.at});

  final String reason;
  final UserId cancelledBy;
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      other is Cancelled && other.reason == reason && other.cancelledBy == cancelledBy && other.at == at;

  @override
  int get hashCode => Object.hash(reason, cancelledBy, at);

  @override
  String toString() => 'Cancelled("$reason" by $cancelledBy at $at)';
}

/// Jedino mesto koje kaže koji prelazi između stanja su dozvoljeni.
bool canTransition(WashStatus from, WashStatus to) => switch ((from, to)) {
  (Submitted(), Accepted()) => true,
  (Submitted() || Accepted(), Cancelled()) => true,
  (Accepted(), InProgress()) => true,
  (Accepted(), Submitted()) => true,
  (InProgress(), Completed()) => true,
  (InProgress(), Cancelled()) => true,
  _ => false,
};
