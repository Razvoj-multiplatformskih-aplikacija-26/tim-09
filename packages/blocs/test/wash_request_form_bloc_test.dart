import 'package:bloc_test/bloc_test.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';
import 'package:use_cases/use_cases.dart';

import 'fake_wash_requests.dart';

final now = DateTime(2026, 10, 26, 9);
const client = UserId('u-client');

WashRequestDraft draft() => WashRequestDraft(
  clientId: client,
  vehicle: Vehicle(type: VehicleType.sedan, plate: LicensePlate.parse('BG 123-AB').valueOrNull!),
  tier: ServiceTier.economy,
  address: Address.parse('Knez Mihailova 6').valueOrNull!,
  slot: WashSlot.parse(DateTime(2026, 10, 27, 10), duration: const Duration(minutes: 45), now: now).valueOrNull!,
);

WashRequest pending(String id) => WashRequest(
  id: WashRequestId(id),
  clientId: client,
  vehicle: Vehicle(type: VehicleType.sedan, plate: LicensePlate.parse('BG 123-AB').valueOrNull!),
  tier: ServiceTier.economy,
  address: Address.parse('Knez Mihailova 6').valueOrNull!,
  slot: WashSlot.existing(DateTime(2026, 10, 27, 10), const Duration(minutes: 45)),
  createdAt: now,
);

WashRequestFormBloc blocWith(FakeWashRequests repository) =>
    WashRequestFormBloc(submitRequest: SubmitRequest(requests: repository));

void main() {
  blocTest<WashRequestFormBloc, WashRequestFormState>(
    'slanje: Submitting, pa Done sa novim prijavljenim zahtevom',
    build: () => blocWith(FakeWashRequests()),
    act: (bloc) => bloc.add(WashRequestFormSubmitted(draft())),
    expect: () => [
      const WashRequestFormSubmitting(),
      isA<WashRequestFormDone>()
          .having((s) => s.request.status, 'status', const Submitted())
          .having((s) => s.request.vehicle.plate.value, 'plate', 'BG 123-AB'),
    ],
  );

  blocTest<WashRequestFormBloc, WashRequestFormState>(
    'tri zahteva na čekanju → Rejected(TooManyPendingRequests)',
    build: () => blocWith(FakeWashRequests([pending('wr-1'), pending('wr-2'), pending('wr-3')])),
    act: (bloc) => bloc.add(WashRequestFormSubmitted(draft())),
    expect: () => [const WashRequestFormSubmitting(), const WashRequestFormRejected(TooManyPendingRequests())],
  );

  blocTest<WashRequestFormBloc, WashRequestFormState>(
    'greška repozitorijuma → Failed',
    build: () => blocWith(FakeWashRequests()..failingRequests = 1),
    act: (bloc) => bloc.add(WashRequestFormSubmitted(draft())),
    expect: () => [const WashRequestFormSubmitting(), isA<WashRequestFormFailed>()],
  );
}
