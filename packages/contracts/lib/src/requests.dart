import 'json_values.dart';

final class VehicleDto {
  const VehicleDto({required this.type, required this.plate});

  factory VehicleDto.fromJson(Map<String, Object?> json) {
    jsonFields(json, {'type', 'plate'});
    return VehicleDto(type: jsonString(json, 'type'), plate: jsonString(json, 'plate'));
  }

  final String type;
  final String plate;

  Map<String, Object?> toJson() => {'type': type, 'plate': plate};
}

final class CreateRequest {
  const CreateRequest({
    required this.vehicle,
    required this.tier,
    required this.address,
    required this.start,
    this.note,
  });

  factory CreateRequest.fromJson(Map<String, Object?> json) {
    jsonFields(json, {'vehicle', 'tier', 'address', 'start', 'note'});
    final address = jsonObject(json['address']);
    jsonFields(address, {'text'});
    return CreateRequest(
      vehicle: VehicleDto.fromJson(jsonObject(json['vehicle'])),
      tier: jsonString(json, 'tier'),
      address: jsonString(address, 'text'),
      start: jsonInstant(json, 'start'),
      note: jsonOptionalString(json, 'note'),
    );
  }

  final VehicleDto vehicle;
  final String tier;
  final String address;
  final DateTime start;
  final String? note;

  Map<String, Object?> toJson() => {
    'vehicle': vehicle.toJson(),
    'tier': tier,
    'address': {'text': address},
    'start': instantJson(start),
    'note': note,
  };
}

final class StatusDto {
  StatusDto({required this.type, Map<String, Object?> data = const {}}) : data = Map.unmodifiable(data);

  factory StatusDto.fromJson(Map<String, Object?> json) =>
      StatusDto(type: jsonString(json, 'type'), data: {...json}..remove('type'));

  final String type;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => {'type': type, ...data};
}

final class WashRequestDto {
  const WashRequestDto({
    required this.id,
    required this.clientId,
    required this.vehicle,
    required this.tier,
    required this.address,
    required this.start,
    required this.durationMinutes,
    required this.createdAt,
    required this.priceRsd,
    required this.status,
    this.note,
  });

  factory WashRequestDto.fromJson(Map<String, Object?> json) {
    final slot = jsonObject(json['slot']);
    if (jsonString(json, 'currency') != 'RSD') throw const FormatException('Unsupported currency.');
    return WashRequestDto(
      id: jsonString(json, 'id'),
      clientId: jsonString(json, 'clientId'),
      vehicle: VehicleDto.fromJson(jsonObject(json['vehicle'])),
      tier: jsonString(json, 'tier'),
      address: jsonString(jsonObject(json['address']), 'text'),
      start: jsonInstant(slot, 'start'),
      durationMinutes: jsonInt(slot, 'durationMinutes'),
      createdAt: jsonInstant(json, 'createdAt'),
      priceRsd: jsonInt(json, 'priceRsd'),
      status: StatusDto.fromJson(jsonObject(json['status'])),
      note: jsonOptionalString(json, 'note'),
    );
  }

  final String id;
  final String clientId;
  final VehicleDto vehicle;
  final String tier;
  final String address;
  final DateTime start;
  final int durationMinutes;
  final DateTime createdAt;
  final int priceRsd;
  final StatusDto status;
  final String? note;

  Map<String, Object?> toJson() => {
    'id': id,
    'clientId': clientId,
    'vehicle': vehicle.toJson(),
    'tier': tier,
    'address': {'text': address},
    'slot': {'start': instantJson(start), 'durationMinutes': durationMinutes},
    'note': note,
    'createdAt': instantJson(createdAt),
    'priceRsd': priceRsd,
    'currency': 'RSD',
    'status': status.toJson(),
  };
}

final class RequestPageDto {
  RequestPageDto({required List<WashRequestDto> items, required this.total, required this.limit, required this.offset})
    : items = List.unmodifiable(items);

  factory RequestPageDto.fromJson(Map<String, Object?> json) {
    final items = json['items'];
    if (items is! List<Object?>) throw const FormatException('Expected a list.');
    return RequestPageDto(
      items: items.map((item) => WashRequestDto.fromJson(jsonObject(item))).toList(),
      total: jsonInt(json, 'total'),
      limit: jsonInt(json, 'limit'),
      offset: jsonInt(json, 'offset'),
    );
  }

  final List<WashRequestDto> items;
  final int total;
  final int limit;
  final int offset;

  Map<String, Object?> toJson() => {
    'items': items.map((item) => item.toJson()).toList(),
    'total': total,
    'limit': limit,
    'offset': offset,
  };
}

final class WasherDto {
  const WasherDto({required this.id, required this.name, required this.hasActiveJob});

  factory WasherDto.fromJson(Map<String, Object?> json) {
    final busy = json['hasActiveJob'];
    if (busy is! bool) throw const FormatException('Expected washer availability.');
    return WasherDto(id: jsonString(json, 'id'), name: jsonString(json, 'name'), hasActiveJob: busy);
  }

  final String id;
  final String name;
  final bool hasActiveJob;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'hasActiveJob': hasActiveJob};
}
