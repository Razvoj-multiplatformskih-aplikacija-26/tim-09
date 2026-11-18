import 'package:api_mapping/api_mapping.dart';
import 'package:contracts/contracts.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 18, 9);
  const user = User(id: UserId('u-client'), username: 'marko', role: Role.client);

  test('svih pet stanja čuva podatke pri prevodu u oba smera', () {
    for (final status in <WashStatus>[
      const Submitted(),
      Accepted(washerId: const WasherId('w-1'), acceptedBy: user.id, at: now),
      InProgress(washerId: const WasherId('w-1'), arrivedAt: now),
      Completed(finishedAt: now),
      Cancelled(reason: 'Promena plana.', cancelledBy: user.id, at: now),
    ]) {
      expect(statusFromDto(StatusDto.fromJson(statusToDto(status).toJson())), status);
    }
  });

  test('sačuvani istorijski podaci ne proveravaju se kao novo zakazivanje', () {
    final original = WashRequest(
      id: const WashRequestId('history'),
      clientId: user.id,
      vehicle: const Vehicle(type: VehicleType.sedan, plate: LicensePlate.existing('OLD')),
      tier: ServiceTier.economy,
      address: const Address.existing('Ranija adresa'),
      slot: WashSlot.existing(now.subtract(const Duration(days: 30)), const Duration(minutes: 45)),
      note: WashNote.existing(List.filled(400, 'a').join()),
      createdAt: now.subtract(const Duration(days: 31)),
      status: Completed(finishedAt: now),
    );
    expect(requestFromDto(WashRequestDto.fromJson(requestToDto(original).toJson())), original);
  });

  test('izmenjena serverska granica ostaje u grešci', () {
    final error = errorFromDto(ApiError(code: 'note_too_long', details: {'actualLength': 250, 'maxLength': 200}));
    expect(error, const NoteTooLong(250, maxLength: 200));
    expect(errorToDto(error).details['maxLength'], 200);
  });

  test('nepoznata ili nepotpuna greška daje kontrolisanu udaljenu grešku', () {
    expect(errorFromDto(ApiError(code: 'new_rule', details: {'limit': 1})), isA<RemoteRuleViolation>());
    expect(errorFromDto(ApiError(code: 'note_too_long')), isA<RemoteRuleViolation>());
  });

  test('podaci svih poznatih grešaka mogu nazad kroz ugovor', () {
    final errors = <DomainError>[
      const NoteTooLong(301),
      const InvalidLicensePlate(),
      const AddressMissing(),
      SlotTooSoon(earliestAllowedStart: now),
      SlotTooFar(latestAllowedStart: now),
      const SlotNotOnHalfHour(),
      const OutsideWorkingHours(),
      const CancellationTooLate(),
      const TooManyPendingRequests(maxPending: 3, currentPending: 3),
      InvalidTransition(
        from: const Submitted(),
        to: Completed(finishedAt: now),
      ),
      const NotAllowed(),
      const NotFound(),
      const WasherBusy(washerId: WasherId('w-1')),
    ];
    for (final error in errors) {
      final dto = errorToDto(error);
      expect(errorToDto(errorFromDto(ApiError.fromJson(dto.toJson()))).toJson(), dto.toJson());
    }
  });
}
