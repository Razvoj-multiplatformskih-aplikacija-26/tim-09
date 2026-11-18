import 'package:api_client/api_client.dart';
import 'package:domain/domain.dart';
import 'package:platform_adapters/platform_adapters.dart';
import 'package:use_cases/testing.dart';
import 'package:use_cases/use_cases.dart';

import 'data/fake_car_wash.dart';

/// Jedino mesto gde se biraju implementacije. Ekrani i Bloc-ovi ne znaju da li rade sa serverom ili fake podacima.
final class AppDependencies {
  AppDependencies({
    required this.clock,
    required this.auth,
    required WashRequestRepository requests,
    this.fakeCarWash,
    this.fakeAuth,
  }) : getMyRequests = GetMyRequests(requests: requests),
       getRequest = GetRequest(requests: requests),
       cancelRequest = CancelRequest(requests: requests),
       submitRequest = SubmitRequest(requests: requests);

  factory AppDependencies.network({required Uri baseUrl, Clock clock = const SystemClock()}) {
    final api = CarWashApi(
      baseUrl: baseUrl,
      client: createHttpClient(),
      session: SessionController(transport: platformTransport),
    );
    return AppDependencies(
      clock: clock,
      auth: HttpAuthRepository(
        api: api,
        application: ClientApplication.mobile,
        storage: platformTransport == SessionTransport.bearer ? SecureSessionStorage() : null,
      ),
      requests: HttpWashRequestRepository(api),
    );
  }

  factory AppDependencies.fake({
    Clock clock = const SystemClock(),
    Duration latency = const Duration(milliseconds: 700),
    User? signedIn = currentClient,
  }) {
    final auth = InMemoryAuth(
      application: ClientApplication.mobile,
      users: demoUsers,
      clock: clock,
      signedIn: signedIn,
    );
    final carWash = createFakeCarWash(clock: clock, currentUser: () => auth.currentUser, latency: latency);
    return AppDependencies(clock: clock, auth: auth, requests: carWash, fakeCarWash: carWash, fakeAuth: auth);
  }

  /// Fiksni korisnici postoje samo za fake konfiguraciju i testove; mrežni rad koristi prijavu.
  static const currentClient = User(id: UserId('u-client'), username: 'marko', role: Role.client);

  static const demoUsers = [
    currentClient,
    User(id: UserId('u-other'), username: 'ana', role: Role.client),
    User(id: UserId('u-dispatcher'), username: 'dispecer', role: Role.dispatcher),
    User(id: UserId('u-washer-1'), username: 'nikola', role: Role.washer, washerId: WasherId('w-1')),
  ];

  final Clock clock;
  final AuthRepository auth;
  final GetMyRequests getMyRequests;
  final GetRequest getRequest;
  final CancelRequest cancelRequest;
  final SubmitRequest submitRequest;
  final InMemoryWashRequests? fakeCarWash;
  final InMemoryAuth? fakeAuth;
}
