import 'package:domain/domain.dart';

import '../dependencies.dart';

const _dispatcher = UserId('u-dispatcher');

/// 12 zahteva trenutnog klijenta, u svakom od pet stanja. Vreme je relativno u odnosu na [now],
/// pa podaci uvek izgledaju sveže: aktivni su danas i sutra, prethodni u proteklim danima.
List<WashRequest> seedRequests(DateTime now) {
  final client = AppDependencies.currentClient.id;

  DateTime day(int offset, int hour, [int minute = 0]) => DateTime(now.year, now.month, now.day + offset, hour, minute);

  WashRequest request(
    String id, {
    required DateTime start,
    required VehicleType type,
    required String plate,
    required ServiceTier tier,
    required String address,
    String? note,
    WashStatus status = const Submitted(),
  }) {
    return WashRequest(
      id: WashRequestId(id),
      clientId: client,
      vehicle: Vehicle(type: type, plate: LicensePlate.parse(plate).valueOrNull!),
      tier: tier,
      address: Address.parse(address).valueOrNull!,
      slot: WashSlot.existing(start, estimate(type, tier).duration),
      note: note == null ? null : WashNote.parse(note).valueOrNull,
      status: status,
      createdAt: start.subtract(const Duration(days: 1)),
    );
  }

  final lateStart = now.subtract(const Duration(minutes: 45));
  final runningStart = now.subtract(const Duration(minutes: 30));

  return [
    // Aktivni: prijavljen, prihvaćen (perač kasni), u toku.
    request(
      'wr-01',
      start: day(1, 10),
      type: VehicleType.sedan,
      plate: 'BG 123-AB',
      tier: ServiceTier.economy,
      address: 'Bulevar kralja Aleksandra 73, Beograd',
      note: 'Auto je na parkingu iza zgrade.',
    ),
    request(
      'wr-02',
      start: lateStart,
      type: VehicleType.suv,
      plate: 'BG 4521-KM',
      tier: ServiceTier.professional,
      address: 'Jurija Gagarina 14, Novi Beograd',
      status: Accepted(washerId: const WasherId('w-1'), acceptedBy: _dispatcher, at: day(-1, 18)),
    ),
    request(
      'wr-03',
      start: runningStart,
      type: VehicleType.hatchback,
      plate: 'NS 882-PT',
      tier: ServiceTier.economy,
      address: 'Knez Mihailova 6, Beograd',
      note: 'Garaža, nivo -2, mesto 41.',
      status: InProgress(arrivedAt: runningStart.add(const Duration(minutes: 5))),
    ),
    // Završeni.
    request(
      'wr-04',
      start: day(-1, 9),
      type: VehicleType.sedan,
      plate: 'BG 123-AB',
      tier: ServiceTier.professional,
      address: 'Bulevar kralja Aleksandra 73, Beograd',
      status: Completed(finishedAt: day(-1, 10, 35)),
    ),
    request(
      'wr-05',
      start: day(-3, 14, 30),
      type: VehicleType.suv,
      plate: 'BG 4521-KM',
      tier: ServiceTier.economy,
      address: 'Jurija Gagarina 14, Novi Beograd',
      status: Completed(finishedAt: day(-3, 15, 35)),
    ),
    request(
      'wr-06',
      start: day(-6, 11),
      type: VehicleType.hatchback,
      plate: 'NS 882-PT',
      tier: ServiceTier.economy,
      address: 'Knez Mihailova 6, Beograd',
      status: Completed(finishedAt: day(-6, 11, 50)),
    ),
    request(
      'wr-07',
      start: day(-10, 16),
      type: VehicleType.van,
      plate: 'BG 909-ZR',
      tier: ServiceTier.professional,
      address: 'Vojvode Stepe 250, Beograd',
      note: 'Kombi je visok 2,4 m.',
      status: Completed(finishedAt: day(-10, 18, 5)),
    ),
    request(
      'wr-08',
      start: day(-15, 8, 30),
      type: VehicleType.sedan,
      plate: 'BG 123-AB',
      tier: ServiceTier.economy,
      address: 'Bulevar kralja Aleksandra 73, Beograd',
      status: Completed(finishedAt: day(-15, 9, 20)),
    ),
    // Otkazani: dva otkazao klijent, dva dispečer.
    request(
      'wr-09',
      start: day(-2, 12),
      type: VehicleType.sedan,
      plate: 'BG 123-AB',
      tier: ServiceTier.economy,
      address: 'Bulevar kralja Aleksandra 73, Beograd',
      status: Cancelled(reason: 'Otkazao klijent.', cancelledBy: client, at: day(-3, 20)),
    ),
    request(
      'wr-10',
      start: day(-4, 17),
      type: VehicleType.suv,
      plate: 'BG 4521-KM',
      tier: ServiceTier.professional,
      address: 'Jurija Gagarina 14, Novi Beograd',
      status: Cancelled(reason: 'Nema slobodnog perača u tom terminu.', cancelledBy: _dispatcher, at: day(-5, 9)),
    ),
    request(
      'wr-11',
      start: day(-8, 10, 30),
      type: VehicleType.hatchback,
      plate: 'NS 882-PT',
      tier: ServiceTier.professional,
      address: 'Knez Mihailova 6, Beograd',
      status: Cancelled(reason: 'Otkazao klijent.', cancelledBy: client, at: day(-9, 13)),
    ),
    request(
      'wr-12',
      start: day(-12, 15),
      type: VehicleType.van,
      plate: 'BG 909-ZR',
      tier: ServiceTier.economy,
      address: 'Vojvode Stepe 250, Beograd',
      status: Cancelled(reason: 'Loše vreme, pranje pomereno.', cancelledBy: _dispatcher, at: day(-12, 8)),
    ),
  ];
}
