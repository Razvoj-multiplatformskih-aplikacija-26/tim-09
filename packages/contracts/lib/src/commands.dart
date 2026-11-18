import 'json_values.dart';
import 'requests.dart';

final class AssignRequest {
  const AssignRequest({required this.washerId});

  factory AssignRequest.fromJson(Map<String, Object?> json) {
    jsonFields(json, {'washerId'});
    return AssignRequest(washerId: jsonString(json, 'washerId'));
  }

  final String washerId;

  Map<String, Object?> toJson() => {'washerId': washerId};
}

final class CancelRequestDto {
  const CancelRequestDto({this.reason = ''});

  factory CancelRequestDto.fromJson(Map<String, Object?> json) {
    jsonFields(json, {'reason'});
    return CancelRequestDto(reason: jsonOptionalString(json, 'reason') ?? '');
  }

  final String reason;

  Map<String, Object?> toJson() => {'reason': reason};
}

final class RequestResponse {
  const RequestResponse(this.request);

  factory RequestResponse.fromJson(Map<String, Object?> json) =>
      RequestResponse(WashRequestDto.fromJson(jsonObject(json['request'])));

  final WashRequestDto request;

  Map<String, Object?> toJson() => {'request': request.toJson()};
}
