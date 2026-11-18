import 'package:domain/domain.dart';
import 'package:use_cases/testing.dart';
import 'package:use_cases/use_cases.dart';

const washerProfiles = [
  Washer(id: WasherId('w-1'), name: 'Nikola Petrović', hasActiveJob: false),
  Washer(id: WasherId('w-2'), name: 'Jovan Ilić', hasActiveJob: false),
];

InMemoryWashRequests fakeRequests(User user, DateTime now, [List<WashRequest> requests = const []]) =>
    InMemoryWashRequests(clock: FixedClock(now), currentUser: () => user, requests: requests, washers: washerProfiles);

RequestPage pageOf(List<WashRequest> items, {int? total, int limit = 20, int offset = 0}) =>
    RequestPage(items: items, total: total ?? items.length, limit: limit, offset: offset);
