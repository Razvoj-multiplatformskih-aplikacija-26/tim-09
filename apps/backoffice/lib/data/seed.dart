import 'package:domain/domain.dart';

import '../dependencies.dart';

/// Zahtevi više klijenata, u svakom od pet stanja. Vreme je relativno u odnosu na [now],
/// pa red čekanja uvek izgleda sveže. Perači w-1 i w-2 imaju aktivan posao, w-3 i w-4 su slobodni.
List<WashRequest> seedRequests(DateTime now) {
  final dispatcher = BackofficeDependencies.currentDispatcher.id;

  DateTime day(int offset, int hour, [int minute = 0]) => DateTime(now.year, now.month, now.day + offset, hour, minute);

  WashRequest request(
    String id, {
    required String client,
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
      clientId: UserId(client),
      vehicle: Vehicle(type: type, plate: LicensePlate.parse(plate).valueOrNull!),
      tier: tier,
      address: Address.parse(address).valueOrNull!,
      slot: WashSlot.existing(start, estimate(type, tier).duration),
      note: note == null ? null : WashNote.parse(note).valueOrNull,
      status: status,
      createdAt: start.subtract(const Duration(days: 1)),
    );
  }

  final runningStart = now.subtract(const Duration(minutes: 30));

  return [
    // Red čekanja: prijavljeni, čekaju perača.
    request(
      'wr-101',
      client: 'u-client',
      start: day(1, 9),
      type: VehicleType.sedan,
      plate: 'BG 123-AB',
      tier: ServiceTier.economy,
      address: 'Bulevar kralja Aleksandra 73, Beograd',
      note: 'Auto je na parkingu iza zgrade.',
    ),
    request(
      'wr-102',
      client: 'u-ana',
      start: day(1, 11, 30),
      type: VehicleType.suv,
      plate: 'NS 4521-KM',
      tier: ServiceTier.professional,
      address: 'Bulevar oslobođenja 15, Novi Sad',
    ),
    request(
      'wr-103',
      client: 'u-petar',
      start: day(2, 14),
      type: VehicleType.van,
      plate: 'NI 789-EF',
      tier: ServiceTier.economy,
      address: 'Obrenovićeva 42, Niš',
      note: 'Kombi je visok 2,4 m.',
    ),
    request(
      'wr-104',
      client: 'u-ana',
      start: day(3, 16, 30),
      type: VehicleType.hatchback,
      plate: 'NS 882-PT',
      tier: ServiceTier.professional,
      address: 'Zmaj Jovina 8, Novi Sad',
    ),
    // Aktivni: perač dodeljen ili već pere.
    request(
      'wr-105',
      client: 'u-petar',
      start: day(1, 8, 30),
      type: VehicleType.sedan,
      plate: 'BG 909-ZR',
      tier: ServiceTier.professional,
      address: 'Vojvode Stepe 250, Beograd',
      status: Accepted(washerId: const WasherId('w-1'), acceptedBy: dispatcher, at: day(-1, 18)),
    ),
    request(
      'wr-106',
      client: 'u-client',
      start: runningStart,
      type: VehicleType.hatchback,
      plate: 'BG 4410-TT',
      tier: ServiceTier.economy,
      address: 'Knez Mihailova 6, Beograd',
      note: 'Garaža, nivo -2, mesto 41.',
      status: InProgress(washerId: const WasherId('w-2'), arrivedAt: runningStart.add(const Duration(minutes: 5))),
    ),
    // Prethodni: završeni i otkazani.
    request(
      'wr-107',
      client: 'u-client',
      start: day(-1, 10),
      type: VehicleType.sedan,
      plate: 'BG 123-AB',
      tier: ServiceTier.professional,
      address: 'Bulevar kralja Aleksandra 73, Beograd',
      status: Completed(finishedAt: day(-1, 11, 35)),
    ),
    request(
      'wr-108',
      client: 'u-ana',
      start: day(-1, 15),
      type: VehicleType.suv,
      plate: 'NS 4521-KM',
      tier: ServiceTier.economy,
      address: 'Bulevar oslobođenja 15, Novi Sad',
      status: Cancelled(reason: 'Otkazao klijent.', cancelledBy: const UserId('u-ana'), at: day(-2, 20)),
    ),
    request(
      'wr-109',
      client: 'u-petar',
      start: day(-2, 12, 30),
      type: VehicleType.van,
      plate: 'NI 789-EF',
      tier: ServiceTier.professional,
      address: 'Obrenovićeva 42, Niš',
      status: Cancelled(reason: 'Nema slobodnog perača u tom terminu.', cancelledBy: dispatcher, at: day(-3, 9)),
    ),
  ];
}
