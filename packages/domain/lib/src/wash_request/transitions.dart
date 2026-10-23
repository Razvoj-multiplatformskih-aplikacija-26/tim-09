import '../errors.dart';
import '../result.dart';
import '../user.dart';
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
bool mayCancel(User by, WashRequest request) =>
    by.role.isStaff || (by.id == request.clientId && request.status is! InProgress);

/// Redosled provera: ovlašćenje → prelaz → rok.
Result<WashRequest> cancelRequest(WashRequest request, {required User by, required DateTime now, String reason = ''}) {
  if (!mayCancel(by, request)) return const Failure(NotAllowed());
  final next = Cancelled(reason: reason, cancelledBy: by.id, at: now);
  if (!canTransition(request.status, next)) return Failure(InvalidTransition(from: request.status, to: next));
  if (by.role == Role.client && !clientMayStillCancel(request, now: now)) return const Failure(CancellationTooLate());
  return Success(request.copyWith(status: next));
}
