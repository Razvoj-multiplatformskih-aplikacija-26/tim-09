import 'package:meta/meta.dart';

import 'wash_request/wash_status.dart';

sealed class DomainError {
  const DomainError();
}

@immutable
final class NoteTooLong extends DomainError {
  const NoteTooLong(this.length);

  final int length;

  @override
  bool operator ==(Object other) => other is NoteTooLong && other.length == length;

  @override
  int get hashCode => Object.hash(NoteTooLong, length);

  @override
  String toString() => 'NoteTooLong($length)';
}

final class InvalidLicensePlate extends DomainError {
  const InvalidLicensePlate();
}

final class AddressMissing extends DomainError {
  const AddressMissing();
}

final class SlotTooSoon extends DomainError {
  const SlotTooSoon();
}

final class SlotTooFar extends DomainError {
  const SlotTooFar();
}

final class SlotNotOnHalfHour extends DomainError {
  const SlotNotOnHalfHour();
}

final class OutsideWorkingHours extends DomainError {
  const OutsideWorkingHours();
}

final class CancellationTooLate extends DomainError {
  const CancellationTooLate();
}

final class TooManyPendingRequests extends DomainError {
  const TooManyPendingRequests();
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
  const WasherBusy();
}
