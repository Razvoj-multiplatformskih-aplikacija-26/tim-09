import 'package:domain/domain.dart';
import 'package:use_cases/testing.dart';
import 'package:use_cases/use_cases.dart';

import 'seed.dart';

const fakeWashers = [
  Washer(id: WasherId('w-1'), name: 'Nikola Petrović', hasActiveJob: false),
  Washer(id: WasherId('w-2'), name: 'Jovan Ilić', hasActiveJob: false),
  Washer(id: WasherId('w-3'), name: 'Stefan Marković', hasActiveJob: false),
  Washer(id: WasherId('w-4'), name: 'Luka Đorđević', hasActiveJob: false),
];

/// Lažna implementacija porta: svi zahtevi u memoriji, sa kašnjenjem kao da idu preko mreže.
InMemoryWashRequests createFakeDispatchRepository({
  required Clock clock,
  required User? Function() currentUser,
  Duration latency = const Duration(milliseconds: 700),
}) => InMemoryWashRequests(
  clock: clock,
  currentUser: currentUser,
  requests: seedRequests(clock.now()),
  washers: fakeWashers,
  latency: latency,
);
