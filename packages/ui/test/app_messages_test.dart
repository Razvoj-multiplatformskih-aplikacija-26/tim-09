import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ui/ui.dart';
import 'package:use_cases/use_cases.dart';

void main() {
  test('mrežne, sesijske i protokol greške imaju korisnički tekst bez tehničkih detalja', () {
    final messages = [
      failureMessage(const NetworkException('SocketException: refused')),
      failureMessage(const NetworkException('timeout', timedOut: true)),
      failureMessage(const NetworkException('reset', outcomeUnknown: true)),
      failureMessage(const SessionExpiredException()),
      failureMessage(const ProtocolException('{"code":"server_error"}', statusCode: 500)),
      failureMessage(StateError('boom')),
    ];
    expect(messages.toSet(), hasLength(messages.length));
    for (final message in messages) {
      expect(message, isNot(matches(RegExp(r'Exception|\{|500|boom'))));
    }
    expect(failureMessage(const NetworkException('reset', outcomeUnknown: true)), contains('Osvežite podatke'));
  });

  test('razlozi prijave zavise od aplikacije', () {
    expect(AuthNotice.wrongApplication.messageFor(ClientApplication.backoffice), 'Backoffice je namenjen dispečerima.');
    expect(AuthNotice.sessionExpired.messageFor(ClientApplication.mobile), 'Prijava je istekla. Prijavite se ponovo.');
    expect(AuthNotice.invalidCredentials.messageFor(ClientApplication.mobile), 'Pogrešno korisničko ime ili lozinka.');
  });

  test('isti trenutak se prikazuje u poslovnoj zoni, nezavisno od zone uređaja', () async {
    await initializeDateFormatting(serbianLatin);
    final instant = DateTime.utc(2026, 11, 19, 9);
    expect(formatTime(instant), '10:00');
    expect(formatTime(instant.toLocal()), '10:00');
    expect(formatDate(DateTime.utc(2026, 11, 19, 23, 30)), 'Petak, 20. novembar');
  });
}
