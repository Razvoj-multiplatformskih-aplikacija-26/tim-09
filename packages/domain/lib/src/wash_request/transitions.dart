import '../errors.dart';
import '../permissions.dart';
import '../result.dart';
import '../user.dart';
import '../identifiers.dart';
import 'wash_request.dart';
import 'wash_status.dart';

/// R4 · Klijent prihvaćen zahtev otkazuje najkasnije [cancellationNotice] pre termina,
/// osim ako perač kasni više od [washerLateAfter] — tada uvek može.
const cancellationNotice = Duration(hours: 1);
const washerLateAfter = Duration(minutes: 30);

bool isWasherLate(WashRequest request, {required DateTime now}) =>
    request.status is Accepted && now.isAfter(request.slot.start.add(washerLateAfter));

bool clientMayStillCancel(WashRequest request, {required DateTime now}) => switch (request.status) {
  Submitted() => true,
  Accepted() => !now.isAfter(request.slot.start.subtract(cancellationNotice)) || isWasherLate(request, now: now),
  InProgress() || Completed() || Cancelled() => false,
};

/// Klijent otkazuje samo svoj zahtev i to dok pranje nije počelo; osoblje može uvek.
bool mayCancel(User by, WashRequest request) => mayCancelRequest(by, request);

/// Redosled provera: ovlašćenje → prelaz → rok.
Result<WashRequest> cancelRequest(WashRequest request, {required User by, required DateTime now, String reason = ''}) {
  if (!mayCancel(by, request)) return const Failure(NotAllowed());
  final next = Cancelled(reason: reason, cancelledBy: by.id, at: now);
  if (!canTransition(request.status, next)) return Failure(InvalidTransition(from: request.status, to: next));
  if (by.role == Role.client && !clientMayStillCancel(request, now: now)) {
    return Failure(
      CancellationTooLate(
        noticeMinutes: cancellationNotice.inMinutes,
        washerLateAfterMinutes: washerLateAfter.inMinutes,
      ),
    );
  }
  return Success(request.copyWith(status: next));
}

/// R3 · Perač ima najviše jedan aktivan posao (prihvaćen ili u toku).
bool washerHasActiveJob(WasherId washer, List<WashRequest> requests) => requests.any(
  (r) => switch (r.status) {
    Accepted(:final washerId) || InProgress(:final washerId) => washerId == washer,
    Submitted() || Completed() || Cancelled() => false,
  },
);

/// Dispečer dodeljuje perača zahtevu uz primenu pravila R3.
Result<WashRequest> acceptRequest(
  WashRequest request, {
  required WasherId washer,
  required User by,
  required DateTime now,
  required List<WashRequest> all,
}) {
  if (!mayAssignRequest(by)) return const Failure(NotAllowed());
  final next = Accepted(washerId: washer, acceptedBy: by.id, at: now);
  if (!canTransition(request.status, next)) {
    return Failure(InvalidTransition(from: request.status, to: next));
  }
  if (washerHasActiveJob(washer, all)) return Failure(WasherBusy(washerId: washer));
  return Success(request.copyWith(status: next));
}

/// Dispečer vraća prihvaćen zahtev nazad u red (Accepted → Submitted).
Result<WashRequest> releaseRequest(WashRequest request, {required User by}) {
  if (!mayReleaseRequest(by)) return const Failure(NotAllowed());
  const next = Submitted();
  if (!canTransition(request.status, next)) {
    return Failure(InvalidTransition(from: request.status, to: next));
  }
  return Success(request.copyWith(status: next));
}
