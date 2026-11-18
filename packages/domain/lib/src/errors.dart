import 'package:meta/meta.dart';

import 'identifiers.dart';
import 'wash_request/wash_status.dart';

sealed class DomainError {
  const DomainError();
}

@immutable
final class NoteTooLong extends DomainError {
  const NoteTooLong(this.length, {this.maxLength = 300});

  final int length;
  final int maxLength;

  @override
  bool operator ==(Object other) => other is NoteTooLong && other.length == length && other.maxLength == maxLength;

  @override
  int get hashCode => Object.hash(NoteTooLong, length, maxLength);

  @override
  String toString() => 'NoteTooLong($length, max $maxLength)';
}

final class InvalidLicensePlate extends DomainError {
  const InvalidLicensePlate({this.example = 'BG 123-AB'});

  final String example;

  @override
  bool operator ==(Object other) => other is InvalidLicensePlate && other.example == example;

  @override
  int get hashCode => Object.hash(InvalidLicensePlate, example);
}

final class AddressMissing extends DomainError {
  const AddressMissing();
}

final class SlotTooSoon extends DomainError {
  const SlotTooSoon({this.minNoticeMinutes = 60, this.earliestAllowedStart});

  final int minNoticeMinutes;
  final DateTime? earliestAllowedStart;

  @override
  bool operator ==(Object other) =>
      other is SlotTooSoon &&
      other.minNoticeMinutes == minNoticeMinutes &&
      other.earliestAllowedStart == earliestAllowedStart;

  @override
  int get hashCode => Object.hash(SlotTooSoon, minNoticeMinutes, earliestAllowedStart);
}

final class SlotTooFar extends DomainError {
  const SlotTooFar({this.maxAdvanceDays = 7, this.latestAllowedStart});

  final int maxAdvanceDays;
  final DateTime? latestAllowedStart;

  @override
  bool operator ==(Object other) =>
      other is SlotTooFar && other.maxAdvanceDays == maxAdvanceDays && other.latestAllowedStart == latestAllowedStart;

  @override
  int get hashCode => Object.hash(SlotTooFar, maxAdvanceDays, latestAllowedStart);
}

final class SlotNotOnHalfHour extends DomainError {
  const SlotNotOnHalfHour({this.stepMinutes = 30});

  final int stepMinutes;

  @override
  bool operator ==(Object other) => other is SlotNotOnHalfHour && other.stepMinutes == stepMinutes;

  @override
  int get hashCode => Object.hash(SlotNotOnHalfHour, stepMinutes);
}

final class OutsideWorkingHours extends DomainError {
  const OutsideWorkingHours({this.openingHour = 8, this.closingHour = 20});

  final int openingHour;
  final int closingHour;

  @override
  bool operator ==(Object other) =>
      other is OutsideWorkingHours && other.openingHour == openingHour && other.closingHour == closingHour;

  @override
  int get hashCode => Object.hash(OutsideWorkingHours, openingHour, closingHour);
}

final class CancellationTooLate extends DomainError {
  const CancellationTooLate({this.noticeMinutes = 60, this.washerLateAfterMinutes = 30});

  final int noticeMinutes;
  final int washerLateAfterMinutes;

  @override
  bool operator ==(Object other) =>
      other is CancellationTooLate &&
      other.noticeMinutes == noticeMinutes &&
      other.washerLateAfterMinutes == washerLateAfterMinutes;

  @override
  int get hashCode => Object.hash(CancellationTooLate, noticeMinutes, washerLateAfterMinutes);
}

final class TooManyPendingRequests extends DomainError {
  const TooManyPendingRequests({this.maxPending = 3, this.currentPending = 0});

  final int maxPending;
  final int currentPending;

  @override
  bool operator ==(Object other) =>
      other is TooManyPendingRequests && other.maxPending == maxPending && other.currentPending == currentPending;

  @override
  int get hashCode => Object.hash(TooManyPendingRequests, maxPending, currentPending);
}

@immutable
final class InvalidTransition extends DomainError {
  const InvalidTransition({required this.from, required this.to});

  final WashStatus from;
  final WashStatus to;

  @override
  bool operator ==(Object other) => other is InvalidTransition && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'InvalidTransition($from → $to)';
}

final class NotAllowed extends DomainError {
  const NotAllowed();
}

final class NotFound extends DomainError {
  const NotFound();
}

final class WasherBusy extends DomainError {
  const WasherBusy({this.washerId});

  final WasherId? washerId;

  @override
  bool operator ==(Object other) => other is WasherBusy && other.washerId == washerId;

  @override
  int get hashCode => Object.hash(WasherBusy, washerId);
}

final class RemoteRuleViolation extends DomainError {
  RemoteRuleViolation(this.code, Map<String, Object?> details) : details = Map.unmodifiable(details);

  final String code;
  final Map<String, Object?> details;
}
