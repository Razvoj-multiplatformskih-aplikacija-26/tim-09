import '../identifiers.dart';
import 'wash_request.dart';
import 'wash_status.dart';

/// R6 · Klijent ima najviše [maxPendingRequests] zahteva koji čekaju pranje (prijavljen ili prihvaćen).
/// Računa se nad listom svih zahteva; konačno odlučuje server (KT2).
const maxPendingRequests = 3;

int pendingRequestsOf(UserId clientId, List<WashRequest> requests) =>
    requests.where((r) => r.clientId == clientId && (r.status is Submitted || r.status is Accepted)).length;

bool canSubmit(UserId clientId, List<WashRequest> requests) =>
    pendingRequestsOf(clientId, requests) < maxPendingRequests;
