import 'package:domain/domain.dart';
import 'package:use_cases/use_cases.dart';

import 'data/fake_dispatch_repository.dart';

typedef Washer = ({WasherId id, String name});

/// Jedino mesto gde se biraju implementacije. Zamena lažnog repozitorijuma
/// serverom menja samo ovaj fajl, ne ekrane i ne Bloc-ove.
final class BackofficeDependencies {
  BackofficeDependencies({
    required this.clock,
    required this.user,
    required WashRequestRepository requests,
    this.fakeRepository,
  }) : getAllRequests = GetAllRequests(requests: requests),
       acceptRequest = AcceptRequest(requests: requests),
       releaseRequest = ReleaseRequest(requests: requests),
       cancelRequest = CancelRequest(requests: requests, clock: clock);

  factory BackofficeDependencies.fake({Clock clock = const SystemClock(), Duration? latency}) {
    final repository = latency == null
        ? FakeDispatchRepository(clock: clock)
        : FakeDispatchRepository(clock: clock, latency: latency);
    return BackofficeDependencies(
      clock: clock,
      user: currentDispatcher,
      requests: repository,
      fakeRepository: repository,
    );
  }

  /// Backoffice u KT1 radi kao jedan, unapred prijavljen dispečer; prijava stiže u KT2.
  static const currentDispatcher = User(id: UserId('u-dispatcher'), username: 'dispečer', role: Role.dispatcher);

  /// Perači su u KT1 fiksni; od KT2 stižu sa servera, uz odobravanje profila.
  static const List<Washer> washers = [
    (id: WasherId('w-1'), name: 'Nikola Petrović'),
    (id: WasherId('w-2'), name: 'Jovan Ilić'),
    (id: WasherId('w-3'), name: 'Stefan Marković'),
    (id: WasherId('w-4'), name: 'Luka Đorđević'),
  ];

  static String washerName(WasherId id) => washers.where((w) => w.id == id).firstOrNull?.name ?? id.value;

  final Clock clock;
  final User user;
  final GetAllRequests getAllRequests;
  final AcceptRequest acceptRequest;
  final ReleaseRequest releaseRequest;
  final CancelRequest cancelRequest;
  final FakeDispatchRepository? fakeRepository;
}
