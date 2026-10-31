part of 'dispatch_bloc.dart';

sealed class DispatchEvent {
  const DispatchEvent();
}

/// Inicijalno učitavanje i ponovni pokušaj.
final class DispatchRequested extends DispatchEvent {
  const DispatchRequested();
}

/// Korisnik je kliknuo na zahtev u tabeli/listi da vidi detalje.
final class DispatchRequestSelected extends DispatchEvent {
  const DispatchRequestSelected(this.id);

  final WashRequestId? id;
}

/// Dispečer dodeljuje perača zahtevu (Pravilo R3).
final class AcceptRequested extends DispatchEvent {
  const AcceptRequested(this.id, this.washerId);

  final WashRequestId id;
  final WasherId washerId;
}

/// Dispečer vraća zahtev u red (Accepted → Submitted).
final class ReleaseRequested extends DispatchEvent {
  const ReleaseRequested(this.id);

  final WashRequestId id;
}

/// Dispečer otkazuje zahtev.
final class DispatchCancelRequested extends DispatchEvent {
  const DispatchCancelRequested(this.id, {this.reason = ''});

  final WashRequestId id;
  final String reason;
}

/// Ekran je prikazao obaveštenje (SnackBar), pa ga brišemo iz stanja.
final class DispatchNoticeAcknowledged extends DispatchEvent {
  const DispatchNoticeAcknowledged();
}