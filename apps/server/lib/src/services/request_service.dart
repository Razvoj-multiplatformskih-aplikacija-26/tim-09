import 'package:api_mapping/api_mapping.dart';
import 'package:contracts/contracts.dart';
import 'package:domain/domain.dart';
import 'package:use_cases/use_cases.dart';

import '../adapters/fake_geocoding_gateway.dart';
import '../ports/geocoding_gateway.dart';
import '../ports/request_store.dart';
import '../security.dart';

final class RequestService {
  const RequestService({
    required this.store,
    this.clock = const SystemClock(),
    this.geocoding = const FakeGeocodingGateway(),
  });

  final RequestStore store;
  final Clock clock;
  final GeocodingGateway geocoding;

  Future<Result<WashRequest>> create(CreateRequest input, User user) {
    if (!mayCreateRequest(user)) return Future.value(const Failure(NotAllowed()));
    return store.transaction((transaction) async {
      await transaction.lockClient(user.id);
      final existing = await transaction.requestsOf(user.id);
      final result = createFromDto(
        input,
        id: WashRequestId('wr-${randomToken()}'),
        by: user,
        now: clock.now().toUtc(),
        existing: existing,
      );
      if (result case Success(:final value)) {
        Coordinates? coordinates;
        try {
          coordinates = await geocoding.locate(value.address.text).timeout(const Duration(seconds: 3));
        } on Exception {
          coordinates = null;
        }
        await transaction.insert(value, latitude: coordinates?.latitude, longitude: coordinates?.longitude);
      }
      return result;
    });
  }

  Future<Result<WashRequest>> assign(WashRequestId id, WasherId washerId, User user) {
    if (!mayAssignRequest(user)) return Future.value(const Failure(NotAllowed()));
    return store.transaction((transaction) async {
      if (!await transaction.lockWasher(washerId)) return const Failure(NotFound());
      final request = await transaction.lockRequest(id);
      if (request == null) return const Failure(NotFound());
      final active = await transaction.activeJobs();
      final result = acceptRequest(request, washer: washerId, by: user, now: clock.now().toUtc(), all: active);
      if (result case Success(:final value)) await transaction.update(value);
      return result;
    });
  }

  Future<Result<WashRequest>> cancel(WashRequestId id, String reason, User user) =>
      store.transaction((transaction) async {
        final request = await transaction.lockRequest(id);
        if (request == null) return const Failure(NotFound());
        final result = cancelRequest(request, by: user, now: clock.now().toUtc(), reason: reason);
        if (result case Success(:final value)) await transaction.update(value);
        return result;
      });

  Future<Result<WashRequest>> release(WashRequestId id, User user) {
    if (!mayReleaseRequest(user)) return Future.value(const Failure(NotAllowed()));
    return store.transaction((transaction) async {
      final request = await transaction.lockRequest(id);
      if (request == null) return const Failure(NotFound());
      final result = releaseRequest(request, by: user);
      if (result case Success(:final value)) await transaction.update(value);
      return result;
    });
  }

  Future<Result<WashRequest>> find(WashRequestId id, User user) async {
    final request = await store.find(id);
    if (request == null) return const Failure(NotFound());
    return mayViewRequest(user, request) ? Success(request) : const Failure(NotAllowed());
  }

  Future<List<Washer>> washers(User user) async {
    if (!mayAssignRequest(user)) return [];
    final profiles = await store.washers();
    final active = await store.activeJobs();
    return profiles
        .map((washer) => Washer(id: washer.id, name: washer.name, hasActiveJob: washerHasActiveJob(washer.id, active)))
        .toList();
  }
}
