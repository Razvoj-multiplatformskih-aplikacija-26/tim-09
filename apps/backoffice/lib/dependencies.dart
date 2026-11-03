import 'package:domain/domain.dart';
import 'package:use_cases/use_cases.dart';

import 'data/fake_dispatch_repository.dart';

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

  /// Backoffice u KT1 radi kao jedan, unapred prijavljen dispečer.
  static const currentDispatcher = User(id: UserId('u-dispatcher'), username: 'dispečer', role: Role.dispatcher);

  static const washers = [
    (id: WasherId('w-1'), name: 'Nikola'),
    (id: WasherId('w-2'), name: 'Jovan'),
    (id: WasherId('w-3'), name: 'Stefan'),
  ];

  final Clock clock;
  final User user;
  final GetAllRequests getAllRequests;
  final AcceptRequest acceptRequest;
  final ReleaseRequest releaseRequest;
  final CancelRequest cancelRequest;
  final FakeDispatchRepository? fakeRepository;
}
