import 'package:domain/domain.dart';
import 'package:use_cases/use_cases.dart';

import 'data/fake_car_wash.dart';

/// Jedino mesto gde se biraju implementacije. Zamena lažnog repozitorijuma
/// (npr. serverom u KT2) menja samo ovaj fajl, ne ekrane i ne Bloc-ove.
final class AppDependencies {
  AppDependencies({required this.clock, required this.user, required WashRequestRepository requests, this.fakeCarWash})
    : getMyRequests = GetMyRequests(requests: requests),
      cancelRequest = CancelRequest(requests: requests, clock: clock),
      submitRequest = SubmitRequest(requests: requests);

  factory AppDependencies.fake({Clock clock = const SystemClock(), Duration? latency}) {
    final carWash = latency == null ? FakeCarWash(clock: clock) : FakeCarWash(clock: clock, latency: latency);
    return AppDependencies(clock: clock, user: currentClient, requests: carWash, fakeCarWash: carWash);
  }

  /// Aplikacija u KT1 radi kao jedan, unapred prijavljen klijent; prijava stiže u KT2.
  static const currentClient = User(id: UserId('u-client'), username: 'marko', role: Role.client);

  final Clock clock;
  final User user;
  final GetMyRequests getMyRequests;
  final CancelRequest cancelRequest;
  final SubmitRequest submitRequest;
  final FakeCarWash? fakeCarWash;
}
