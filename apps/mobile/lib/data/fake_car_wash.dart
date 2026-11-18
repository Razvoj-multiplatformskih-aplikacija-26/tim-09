import 'package:domain/domain.dart';
import 'package:use_cases/testing.dart';
import 'package:use_cases/use_cases.dart';

import 'seed.dart';

/// Lažna implementacija porta: podaci u memoriji, sa kašnjenjem kao da idu preko mreže.
InMemoryWashRequests createFakeCarWash({
  required Clock clock,
  required User? Function() currentUser,
  Duration latency = const Duration(milliseconds: 700),
}) =>
    InMemoryWashRequests(clock: clock, currentUser: currentUser, requests: seedRequests(clock.now()), latency: latency);
