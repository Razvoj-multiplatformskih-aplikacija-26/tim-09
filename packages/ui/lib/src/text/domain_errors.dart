import 'package:domain/domain.dart';

/// Jedino mesto gde greška iz domena postaje tekst. Nema `default` grane:
/// nova greška u domenu je greška pri prevođenju dok se ovde ne doda poruka.
extension DomainErrorMessage on DomainError {
  String get message => switch (this) {
    NoteTooLong(:final maxLength) => 'Napomena može imati najviše $maxLength znakova.',
    InvalidLicensePlate(:final example) => 'Registarska oznaka mora biti u formatu „$example“.',
    AddressMissing() => 'Unesite adresu na kojoj je vozilo.',
    SlotTooSoon(:final minNoticeMinutes) => 'Termin mora biti najmanje ${_notice(minNoticeMinutes)} od sada.',
    SlotTooFar(:final maxAdvanceDays) => 'Termin može biti najviše $maxAdvanceDays dana unapred.',
    SlotNotOnHalfHour() => 'Termin počinje na pun sat ili pola sata.',
    OutsideWorkingHours(:final openingHour, :final closingHour) =>
      'Pranje mora da počne i završi se između $openingHour i $closingHour h.',
    CancellationTooLate(:final noticeMinutes) =>
      'Otkazivanje je moguće najkasnije ${_notice(noticeMinutes)} pre termina.',
    TooManyPendingRequests(:final maxPending) => 'Možete imati najviše $maxPending zahteva na čekanju.',
    InvalidTransition() => 'Ova promena zahteva nije moguća.',
    NotAllowed() => 'Nemate pravo na ovu radnju.',
    NotFound() => 'Zahtev nije pronađen.',
    WasherBusy() => 'Perač je trenutno zauzet drugim poslom.',
    RemoteRuleViolation() => 'Zahtev nije prihvaćen. Osvežite podatke i pokušajte ponovo.',
  };
}

String _notice(int minutes) => minutes % 60 == 0 ? '${minutes ~/ 60} h' : '$minutes min';
