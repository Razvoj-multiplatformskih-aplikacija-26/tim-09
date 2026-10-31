import 'package:domain/domain.dart';
import 'package:use_cases/use_cases.dart';

class LocalClock implements Clock {
  @override
  DateTime now() => DateTime.now();
}

class FakeDispatchRepository implements WashRequestRepository {
  bool simulateError = false;

  final List<WashRequest> _requests = List.generate(12, (index) {
    final id = 'req-${index + 1}';
    return WashRequest(
      id: WashRequestId(id),
      clientId: UserId('client-${index + 1}'),
      vehicle: Vehicle(
        type: index.isEven ? VehicleType.sedan : VehicleType.suv,
        plate: LicensePlate.parse('BG ${100 + index}-AB').valueOrNull!,
      ),
      tier: ServiceTier.values[index % ServiceTier.values.length],
      address: Address.parse('Ulica ${index + 1}, Beograd').valueOrNull!,
      slot: WashSlot.existing(
        DateTime.now().add(Duration(hours: index + 1)),
        const Duration(minutes: 45),
      ),
      status: const Submitted(),
      createdAt: DateTime.now().subtract(Duration(minutes: index * 15)),
    );
  });

  @override
  Future<List<WashRequest>> allRequests() async {
    if (simulateError) {
      throw Exception('Simulirana greška mreže/servera!');
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List.of(_requests);
  }

  @override
  Future<WashRequest?> find(WashRequestId id) async =>
      _requests.where((r) => r.id == id).firstOrNull;

  @override
  Future<List<WashRequest>> requestsOf(UserId clientId) async => _requests;

  @override
  Future<WashRequest> create(WashRequestDraft draft) async => _requests.first;

  @override
  Future<WashRequest> save(WashRequest request) async {
    final index = _requests.indexWhere((r) => r.id == request.id);
    if (index != -1) _requests[index] = request;
    return request;
  }
}