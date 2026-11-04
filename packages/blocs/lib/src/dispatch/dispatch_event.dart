part of 'dispatch_bloc.dart';

sealed class DispatchEvent {
  const DispatchEvent();
}

/// Inicijalno učitavanje i ponovni pokušaj.
final class DispatchRequested extends DispatchEvent {
  const DispatchRequested();
}

/// Dispečer je izabrao zahtev u listi; `null` poništava izbor.
final class DispatchRequestSelected extends DispatchEvent {
  const DispatchRequestSelected(this.id);

  final WashRequestId? id;
}

/// Dispečer dodeljuje perača zahtevu; domen proverava da perač nema drugi aktivan posao.
final class DispatchAcceptRequested extends DispatchEvent {
  const DispatchAcceptRequested(this.id, this.washerId);

  final WashRequestId id;
  final WasherId washerId;
}

/// Dispečer vraća zahtev u red (Accepted → Submitted).
final class DispatchReleaseRequested extends DispatchEvent {
  const DispatchReleaseRequested(this.id);

  final WashRequestId id;
}

/// Dispečer otkazuje zahtev.
final class DispatchCancelRequested extends DispatchEvent {
  const DispatchCancelRequested(this.id, {this.reason = ''});

  final WashRequestId id;
  final String reason;
}

/// Ekran je prikazao obaveštenje, pa se ono briše iz stanja.
final class DispatchNoticeAcknowledged extends DispatchEvent {
  const DispatchNoticeAcknowledged();
}
