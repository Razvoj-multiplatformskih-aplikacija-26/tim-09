import 'package:domain/domain.dart';

/// Jedino mesto gde greška iz domena postaje tekst. Nema `default` grane:
/// nova greška u domenu je greška pri prevođenju dok se ovde ne doda poruka.
extension DomainErrorMessage on DomainError {
  String get message => switch (this) {
    NoteTooLong() => 'Napomena može imati najviše ${WashNote.maxLength} znakova.',
    InvalidLicensePlate() => 'Registarska oznaka mora biti u formatu „${LicensePlate.example}“.',
    AddressMissing() => 'Unesite adresu na kojoj je vozilo.',
    SlotTooSoon() => 'Termin mora biti najmanje ${WashSlot.minNotice.inHours} h od sada.',
    SlotTooFar() => 'Termin može biti najviše ${WashSlot.maxAdvance.inDays} dana unapred.',
    SlotNotOnHalfHour() => 'Termin počinje na pun sat ili pola sata.',
    OutsideWorkingHours() =>
      'Pranje mora da počne i završi se između ${WashSlot.openingHour} i ${WashSlot.closingHour} h.',
    CancellationTooLate() => 'Otkazivanje je moguće najkasnije ${cancellationNotice.inHours} h pre termina.',
    TooManyPendingRequests() => 'Možete imati najviše $maxPendingRequests zahteva na čekanju.',
    InvalidTransition() => 'Ova promena zahteva nije moguća.',
    NotAllowed() => 'Nemate pravo na ovu radnju.',
    NotFound() => 'Zahtev nije pronađen.',
    WasherBusy() => 'Perač je trenutno zauzet drugim poslom.',
  };
}
