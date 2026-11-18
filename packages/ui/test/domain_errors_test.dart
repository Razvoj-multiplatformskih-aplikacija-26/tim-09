import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

void main() {
  test('poruka koristi granicu dobijenu od servera', () {
    expect(const NoteTooLong(250, maxLength: 200).message, 'Napomena može imati najviše 200 znakova.');
    expect(const TooManyPendingRequests(maxPending: 2).message, 'Možete imati najviše 2 zahteva na čekanju.');
    expect(const SlotTooSoon(minNoticeMinutes: 90).message, 'Termin mora biti najmanje 90 min od sada.');
    expect(
      const CancellationTooLate(noticeMinutes: 30).message,
      'Otkazivanje je moguće najkasnije 30 min pre termina.',
    );
  });

  test('nepoznato pravilo ima korisničku poruku', () {
    expect(RemoteRuleViolation('new_rule', {}).message, 'Zahtev nije prihvaćen. Osvežite podatke i pokušajte ponovo.');
  });
}
