part of 'dispatch_bloc.dart';

sealed class DispatchEvent {
  const DispatchEvent();
}

/// Inicijalno učitavanje, osvežavanje tekuće stranice i ponovni pokušaj.
final class DispatchRequested extends DispatchEvent {
  const DispatchRequested();
}

final class DispatchPageRequested extends DispatchEvent {
  const DispatchPageRequested(this.offset);

  final int offset;
}

final class DispatchFilterChanged extends DispatchEvent {
  const DispatchFilterChanged(this.filter);

  final RequestStatusFilter? filter;
}

/// Dispečer je izabrao zahtev u listi; `null` poništava izbor.
final class DispatchRequestSelected extends DispatchEvent {
  const DispatchRequestSelected(this.id);

  final WashRequestId? id;
}

/// Dispečer dodeljuje perača zahtevu; server proverava da perač nema drugi aktivan posao.
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
