import 'package:api_mapping/api_mapping.dart';
import 'package:contracts/contracts.dart';
import 'package:domain/domain.dart';
import 'package:use_cases/use_cases.dart';

import 'car_wash_api.dart';

final class HttpWasherRepository implements WasherRepository {
  const HttpWasherRepository(this.api);

  final CarWashApi api;

  @override
  Future<List<Washer>> washers() async {
    final result = await api.get('/washers');
    return switch (result) {
      ApiOk(:final json) => readContract(json, (json) {
        final items = json['items'];
        if (items is! List<Object?>) throw const FormatException('Expected a list.');
        return items.map((item) => washerFromDto(WasherDto.fromJson(jsonObject(item)))).toList();
      }),
      ApiRejected(:final status, :final error) => throw ProtocolException(error.code, statusCode: status),
    };
  }
}
