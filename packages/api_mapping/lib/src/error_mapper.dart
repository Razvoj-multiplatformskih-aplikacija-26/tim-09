import 'package:contracts/contracts.dart';
import 'package:domain/domain.dart';

import 'request_mapper.dart';

ApiError errorToDto(DomainError error) => switch (error) {
  NoteTooLong(:final length, :final maxLength) => ApiError(
    code: 'note_too_long',
    details: {'actualLength': length, 'maxLength': maxLength},
  ),
  InvalidLicensePlate(:final example) => ApiError(code: 'invalid_license_plate', details: {'example': example}),
  AddressMissing() => ApiError(code: 'address_missing'),
  SlotTooSoon(:final minNoticeMinutes, :final earliestAllowedStart) => ApiError(
    code: 'slot_too_soon',
    details: {
      'minNoticeMinutes': minNoticeMinutes,
      if (earliestAllowedStart != null) 'earliestAllowedStart': instantJson(earliestAllowedStart),
    },
  ),
  SlotTooFar(:final maxAdvanceDays, :final latestAllowedStart) => ApiError(
    code: 'slot_too_far',
    details: {
      'maxAdvanceDays': maxAdvanceDays,
      if (latestAllowedStart != null) 'latestAllowedStart': instantJson(latestAllowedStart),
    },
  ),
  SlotNotOnHalfHour(:final stepMinutes) => ApiError(
    code: 'slot_not_on_half_hour',
    details: {'stepMinutes': stepMinutes},
  ),
  OutsideWorkingHours(:final openingHour, :final closingHour) => ApiError(
    code: 'outside_working_hours',
    details: {'openingHour': openingHour, 'closingHour': closingHour, 'businessTimeZone': businessTimeZone},
  ),
  CancellationTooLate(:final noticeMinutes, :final washerLateAfterMinutes) => ApiError(
    code: 'cancellation_too_late',
    details: {'noticeMinutes': noticeMinutes, 'washerLateAfterMinutes': washerLateAfterMinutes},
  ),
  TooManyPendingRequests(:final maxPending, :final currentPending) => ApiError(
    code: 'too_many_pending_requests',
    details: {'maxPending': maxPending, 'currentPending': currentPending},
  ),
  InvalidTransition(:final from, :final to) => ApiError(
    code: 'invalid_transition',
    details: {'from': statusToDto(from).toJson(), 'to': statusToDto(to).toJson()},
  ),
  NotAllowed() => ApiError(code: 'not_allowed'),
  NotFound() => ApiError(code: 'not_found'),
  WasherBusy(:final washerId) => ApiError(
    code: 'washer_busy',
    details: {if (washerId != null) 'washerId': washerId.value},
  ),
  RemoteRuleViolation(:final code, :final details) => ApiError(code: code, details: details),
};

DomainError errorFromDto(ApiError error) {
  final data = error.details;
  try {
    return switch (error.code) {
      'note_too_long' => NoteTooLong(jsonInt(data, 'actualLength'), maxLength: jsonInt(data, 'maxLength')),
      'invalid_license_plate' => InvalidLicensePlate(example: jsonString(data, 'example')),
      'address_missing' => const AddressMissing(),
      'slot_too_soon' => SlotTooSoon(
        minNoticeMinutes: jsonInt(data, 'minNoticeMinutes'),
        earliestAllowedStart: data['earliestAllowedStart'] == null ? null : jsonInstant(data, 'earliestAllowedStart'),
      ),
      'slot_too_far' => SlotTooFar(
        maxAdvanceDays: jsonInt(data, 'maxAdvanceDays'),
        latestAllowedStart: data['latestAllowedStart'] == null ? null : jsonInstant(data, 'latestAllowedStart'),
      ),
      'slot_not_on_half_hour' => SlotNotOnHalfHour(stepMinutes: jsonInt(data, 'stepMinutes')),
      'outside_working_hours' => OutsideWorkingHours(
        openingHour: jsonInt(data, 'openingHour'),
        closingHour: jsonInt(data, 'closingHour'),
      ),
      'cancellation_too_late' => CancellationTooLate(
        noticeMinutes: jsonInt(data, 'noticeMinutes'),
        washerLateAfterMinutes: jsonInt(data, 'washerLateAfterMinutes'),
      ),
      'too_many_pending_requests' => TooManyPendingRequests(
        maxPending: jsonInt(data, 'maxPending'),
        currentPending: jsonInt(data, 'currentPending'),
      ),
      'invalid_transition' => InvalidTransition(
        from: statusFromDto(StatusDto.fromJson(jsonObject(data['from']))),
        to: statusFromDto(StatusDto.fromJson(jsonObject(data['to']))),
      ),
      'not_allowed' => const NotAllowed(),
      'not_found' => const NotFound(),
      'washer_busy' => WasherBusy(washerId: data['washerId'] == null ? null : WasherId(jsonString(data, 'washerId'))),
      _ => RemoteRuleViolation(error.code, data),
    };
  } on FormatException {
    return RemoteRuleViolation(error.code, data);
  }
}

int errorStatus(DomainError error) => switch (error) {
  NotAllowed() => 403,
  NotFound() => 404,
  WasherBusy() || TooManyPendingRequests() || InvalidTransition() => 409,
  _ => 422,
};
