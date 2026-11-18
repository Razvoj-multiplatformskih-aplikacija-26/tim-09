import 'package:bloc_test/bloc_test.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:use_cases/testing.dart';
import 'package:use_cases/use_cases.dart';

final now = DateTime.utc(2026, 11, 18, 9);
const marko = User(id: UserId('u-client'), username: 'marko', role: Role.client);
const ana = User(id: UserId('u-other'), username: 'ana', role: Role.client);
const dispatcher = User(id: UserId('u-dispatcher'), username: 'dispecer', role: Role.dispatcher);

InMemoryAuth authOf({User? signedIn, ClientApplication application = ClientApplication.mobile}) => InMemoryAuth(
  application: application,
  users: const [marko, ana, dispatcher],
  clock: FixedClock(now),
  signedIn: signedIn,
);

Session sessionOf(User user) => Session(user: user, expiresAt: now.add(const Duration(hours: 1)));

void main() {
  group('početna provera', () {
    blocTest<AuthBloc, AuthState>(
      'sačuvana sesija se obnavlja',
      build: () => AuthBloc(auth: authOf(signedIn: marko)),
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => [const AuthChecking(), AuthSignedIn(sessionOf(marko))],
    );

    blocTest<AuthBloc, AuthState>(
      'bez sesije → prijava',
      build: () => AuthBloc(auth: authOf()),
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => [const AuthChecking(), const AuthSignedOut()],
    );

    blocTest<AuthBloc, AuthState>(
      'privremeni prekid mreže nudi ponovni pokušaj i ne briše prijavu',
      build: () => AuthBloc(auth: authOf(signedIn: marko)..failingRequests = 1),
      act: (bloc) async {
        bloc.add(const AuthStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const AuthStarted());
      },
      expect: () => [
        const AuthChecking(),
        isA<AuthRestoreFailed>(),
        const AuthChecking(),
        AuthSignedIn(sessionOf(marko)),
      ],
    );
  });

  group('prijava', () {
    blocTest<AuthBloc, AuthState>(
      'ispravni podaci → prijavljen korisnik',
      build: () => AuthBloc(auth: authOf()),
      seed: () => const AuthSignedOut(),
      act: (bloc) => bloc.add(const AuthLoginSubmitted(username: 'marko', password: 'DemoPass123!')),
      expect: () => [const AuthSignedOut(submitting: true), AuthSignedIn(sessionOf(marko))],
    );

    blocTest<AuthBloc, AuthState>(
      'pogrešna lozinka → invalidCredentials, ne istek sesije',
      build: () => AuthBloc(auth: authOf()),
      seed: () => const AuthSignedOut(),
      act: (bloc) => bloc.add(const AuthLoginSubmitted(username: 'marko', password: 'x')),
      expect: () => [const AuthSignedOut(submitting: true), const AuthSignedOut(notice: AuthNotice.invalidCredentials)],
    );

    blocTest<AuthBloc, AuthState>(
      'klijent u backoffice-u → wrongApplication',
      build: () => AuthBloc(auth: authOf(application: ClientApplication.backoffice)),
      seed: () => const AuthSignedOut(),
      act: (bloc) => bloc.add(const AuthLoginSubmitted(username: 'marko', password: 'DemoPass123!')),
      expect: () => [const AuthSignedOut(submitting: true), const AuthSignedOut(notice: AuthNotice.wrongApplication)],
    );

    blocTest<AuthBloc, AuthState>(
      'server nedostupan → unavailable i završeno učitavanje',
      build: () => AuthBloc(auth: authOf()..failingRequests = 1),
      seed: () => const AuthSignedOut(),
      act: (bloc) => bloc.add(const AuthLoginSubmitted(username: 'marko', password: 'DemoPass123!')),
      expect: () => [const AuthSignedOut(submitting: true), const AuthSignedOut(notice: AuthNotice.unavailable)],
    );

    test('događaj prijave ne ispisuje lozinku', () {
      expect(const AuthLoginSubmitted(username: 'marko', password: 'tajna').toString(), isNot(contains('tajna')));
    });
  });

  group('odjava i istek', () {
    blocTest<AuthBloc, AuthState>(
      'odjava opoziva sesiju',
      build: () => AuthBloc(auth: authOf(signedIn: marko)),
      seed: () => AuthSignedIn(sessionOf(marko)),
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => [AuthSignedIn(sessionOf(marko), signingOut: true), const AuthSignedOut()],
    );

    blocTest<AuthBloc, AuthState>(
      'neuspešna odjava ostavlja korisnika prijavljenog uz poruku',
      build: () => AuthBloc(auth: authOf(signedIn: marko)..failingRequests = 1),
      seed: () => AuthSignedIn(sessionOf(marko)),
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => [
        AuthSignedIn(sessionOf(marko), signingOut: true),
        AuthSignedIn(sessionOf(marko), notice: AuthNotice.logoutFailed),
      ],
    );

    late InMemoryAuth auth;
    blocTest<AuthBloc, AuthState>(
      'više paralelnih isteka daje jedno preusmeravanje',
      build: () => AuthBloc(auth: auth = authOf(signedIn: marko)),
      seed: () => AuthSignedIn(sessionOf(marko)),
      act: (bloc) {
        auth
          ..expire()
          ..expire()
          ..expire();
      },
      expect: () => [const AuthSignedOut(notice: AuthNotice.sessionExpired)],
    );

    blocTest<AuthBloc, AuthState>(
      'zakasneli istek stare sesije ne odjavljuje novi nalog dok traje prijava',
      build: () => AuthBloc(auth: auth = authOf()),
      seed: () => const AuthSignedOut(submitting: true),
      act: (bloc) => auth.expire(),
      expect: () => const <AuthState>[],
    );
  });
}
