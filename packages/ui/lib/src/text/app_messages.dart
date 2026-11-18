import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:use_cases/use_cases.dart';

String failureMessage(Object cause) => switch (cause) {
  NetworkException(outcomeUnknown: true) =>
    'Veza je prekinuta pre odgovora servera. Osvežite podatke pre ponovnog slanja.',
  NetworkException(timedOut: true) => 'Server ne odgovara na vreme. Pokušajte ponovo.',
  NetworkException() => 'Server nije dostupan. Proverite vezu i pokušajte ponovo.',
  SessionExpiredException() => sessionExpiredMessage,
  ProtocolException() => 'Server je vratio neočekivan odgovor. Pokušajte ponovo.',
  _ => 'Došlo je do greške. Pokušajte ponovo.',
};

const sessionExpiredMessage = 'Prijava je istekla. Prijavite se ponovo.';

extension AuthNoticeMessage on AuthNotice {
  String messageFor(ClientApplication application) => switch (this) {
    AuthNotice.invalidCredentials => 'Pogrešno korisničko ime ili lozinka.',
    AuthNotice.wrongApplication => switch (application) {
      ClientApplication.backoffice => 'Backoffice je namenjen dispečerima.',
      ClientApplication.mobile => 'Mobilna aplikacija je namenjena klijentima i peračima.',
    },
    AuthNotice.unavailable => 'Prijava trenutno nije moguća. Proverite vezu i pokušajte ponovo.',
    AuthNotice.sessionExpired => sessionExpiredMessage,
    AuthNotice.logoutFailed => 'Odjava nije potvrđena. Proverite vezu i pokušajte ponovo.',
  };
}

extension RoleLabel on Role {
  String get label => switch (this) {
    Role.client => 'Klijent',
    Role.washer => 'Perač',
    Role.dispatcher => 'Dispečer',
  };
}
