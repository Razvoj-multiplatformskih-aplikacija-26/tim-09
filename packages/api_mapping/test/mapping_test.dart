import 'package:api_mapping/api_mapping.dart';
import 'package:contracts/contracts.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:use_cases/use_cases.dart';

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
      quotedPrice: estimate(VehicleType.sedan, ServiceTier.economy),
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

  group('klijentski read model', () {
    Map<String, Object?> json({int priceRsd = 1550, int durationMinutes = 50}) => {
      'id': 'wr-1',
      'clientId': 'u-client',
      'vehicle': {'type': 'sedan', 'plate': 'BG 123-AB'},
      'tier': 'economy',
      'address': {'text': 'Knez Mihailova 6'},
      'slot': {'start': '2026-11-19T09:00:00Z', 'durationMinutes': durationMinutes},
      'note': null,
      'createdAt': '2026-11-18T09:00:00Z',
      'priceRsd': priceRsd,
      'currency': 'RSD',
      'status': {'type': 'submitted'},
    };

    test('serverska cena različita od lokalnog cenovnika ostaje u modelu', () {
      final request = requestFromDto(WashRequestDto.fromJson(json()));
      expect(estimate(VehicleType.sedan, ServiceTier.economy).priceRsd, isNot(1550));
      expect(request.price, const PriceEstimate(priceRsd: 1550, duration: Duration(minutes: 50)));
      expect(request.copyWith(status: Completed(finishedAt: now)).price.priceRsd, 1550);
      expect(requestToDto(request).priceRsd, 1550);
      expect(requestFromDto(WashRequestDto.fromJson(requestToDto(request).toJson())), request);
    });

    test('stranica zadržava total, limit i offset', () {
      final page = requestPageFromDto(
        RequestPageDto.fromJson({
          'items': [json()],
          'total': 41,
          'limit': 20,
          'offset': 20,
        }),
      );
      expect(page.items.single.id, const WashRequestId('wr-1'));
      expect((page.total, page.limit, page.offset), (41, 20, 20));
    });

    test('nacrt ne šalje vlasnika, cenu, trajanje ni stanje', () {
      final draft = WashRequestDraft(
        vehicle: Vehicle(type: VehicleType.suv, plate: LicensePlate.parse('bg 123-ab').valueOrNull!),
        tier: ServiceTier.professional,
        address: Address.parse('Nemanjina 4').valueOrNull!,
        slot: WashSlot.existing(businessDate(2026, 11, 19, 10), const Duration(hours: 2)),
        note: WashNote.parse('Garaža').valueOrNull,
      );
      final body = draftToDto(draft).toJson();
      expect(body, {
        'vehicle': {'type': 'suv', 'plate': 'BG 123-AB'},
        'tier': 'professional',
        'address': {'text': 'Nemanjina 4'},
        'start': '2026-11-19T09:00:00.000Z',
        'note': 'Garaža',
      });
      expect(CreateRequest.fromJson(body).start, DateTime.utc(2026, 11, 19, 9));
    });

    test('upit nosi opseg, stranicu i filter u nazivima ugovora', () {
      expect(
        queryToDto(
          const RequestQuery(scope: RequestScope.all, limit: 50, offset: 100, status: RequestStatusFilter.inProgress),
        ),
        {'scope': 'all', 'limit': '50', 'offset': '100', 'status': 'in_progress'},
      );
      expect(queryToDto(const RequestQuery(scope: RequestScope.mine)), {'scope': 'mine', 'limit': '20', 'offset': '0'});
    });
  });
}
