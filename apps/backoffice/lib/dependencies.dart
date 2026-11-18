import 'package:api_client/api_client.dart';
import 'package:domain/domain.dart';
import 'package:platform_adapters/platform_adapters.dart';
import 'package:use_cases/testing.dart';
import 'package:use_cases/use_cases.dart';

import 'data/fake_dispatch_repository.dart';

/// Jedino mesto gde se biraju implementacije. Ekrani i Bloc-ovi ne znaju da li rade sa serverom ili fake podacima.
final class BackofficeDependencies {
  BackofficeDependencies({
    required this.clock,
    required this.auth,
    required WashRequestRepository requests,
    required WasherRepository washers,
    this.fakeRepository,
    this.fakeAuth,
  }) : getAllRequests = GetAllRequests(requests: requests),
       getRequest = GetRequest(requests: requests),
       getWashers = GetWashers(washers: washers),
       acceptRequest = AcceptRequest(requests: requests),
       releaseRequest = ReleaseRequest(requests: requests),
       cancelRequest = CancelRequest(requests: requests);

  factory BackofficeDependencies.network({required Uri baseUrl, Clock clock = const SystemClock()}) {
    final api = CarWashApi(
      baseUrl: baseUrl,
      client: createHttpClient(),
      session: SessionController(transport: platformTransport),
    );
    return BackofficeDependencies(
      clock: clock,
      auth: HttpAuthRepository(
        api: api,
        application: ClientApplication.backoffice,
        storage: platformTransport == SessionTransport.bearer ? SecureSessionStorage() : null,
      ),
      requests: HttpWashRequestRepository(api),
      washers: HttpWasherRepository(api),
    );
  }

  factory BackofficeDependencies.fake({
    Clock clock = const SystemClock(),
    Duration latency = const Duration(milliseconds: 700),
    User? signedIn = currentDispatcher,
  }) {
    final auth = InMemoryAuth(
      application: ClientApplication.backoffice,
      users: demoUsers,
      clock: clock,
      signedIn: signedIn,
    );
    final repository = createFakeDispatchRepository(
      clock: clock,
      currentUser: () => auth.currentUser,
      latency: latency,
    );
    return BackofficeDependencies(
      clock: clock,
      auth: auth,
      requests: repository,
      washers: repository,
      fakeRepository: repository,
      fakeAuth: auth,
    );
  }

  /// Fiksni korisnici i perači postoje samo za fake konfiguraciju i testove; mrežni rad ih dobija sa servera.
  static const currentDispatcher = User(id: UserId('u-dispatcher'), username: 'dispecer', role: Role.dispatcher);

  static const demoUsers = [currentDispatcher, User(id: UserId('u-client'), username: 'marko', role: Role.client)];

  final Clock clock;
  final AuthRepository auth;
  final GetAllRequests getAllRequests;
  final GetRequest getRequest;
  final GetWashers getWashers;
  final AcceptRequest acceptRequest;
  final ReleaseRequest releaseRequest;
  final CancelRequest cancelRequest;
  final InMemoryWashRequests? fakeRepository;
  final InMemoryAuth? fakeAuth;
}
