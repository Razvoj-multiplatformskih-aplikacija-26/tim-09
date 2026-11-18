import '../errors.dart';
import '../identifiers.dart';
import '../permissions.dart';
import '../pricing.dart';
import '../result.dart';
import '../user.dart';
import 'address.dart';
import 'license_plate.dart';
import 'pending_requests.dart';
import 'vehicle.dart';
import 'wash_note.dart';
import 'wash_request.dart';
import 'wash_slot.dart';

Result<WashRequest> createWashRequest({
  required WashRequestId id,
  required User by,
  required VehicleType vehicleType,
  required String plate,
  required ServiceTier tier,
  required String address,
  required DateTime start,
  required DateTime now,
  required List<WashRequest> existing,
  String? note,
}) {
  if (!mayCreateRequest(by)) return const Failure(NotAllowed());
  final parsedPlate = LicensePlate.parse(plate);
  if (parsedPlate case Failure(:final error)) return Failure(error);
  final parsedAddress = Address.parse(address);
  if (parsedAddress case Failure(:final error)) return Failure(error);
  final parsedNote = WashNote.parse(note ?? '');
  if (parsedNote case Failure(:final error)) return Failure(error);
  final price = estimate(vehicleType, tier);
  final slot = WashSlot.parse(start, duration: price.duration, now: now);
  if (slot case Failure(:final error)) return Failure(error);
  if (!canSubmit(by.id, existing)) {
    return Failure(
      TooManyPendingRequests(maxPending: maxPendingRequests, currentPending: pendingRequestsOf(by.id, existing)),
    );
  }
  return Success(
    WashRequest(
      id: id,
      clientId: by.id,
      vehicle: Vehicle(type: vehicleType, plate: parsedPlate.valueOrNull!),
      tier: tier,
      address: parsedAddress.valueOrNull!,
      slot: slot.valueOrNull!,
      note: parsedNote.valueOrNull!.text.isEmpty ? null : parsedNote.valueOrNull,
      createdAt: now,
    ),
  );
}
