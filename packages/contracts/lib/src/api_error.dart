import 'json_values.dart';

final class ApiError {
  ApiError({required this.code, Map<String, Object?> details = const {}}) : details = Map.unmodifiable(details);

  factory ApiError.fromJson(Map<String, Object?> json) =>
      ApiError(code: jsonString(json, 'code'), details: jsonObject(json['details'] ?? <String, Object?>{}));

  final String code;
  final Map<String, Object?> details;

  Map<String, Object?> toJson() => {'code': code, 'details': details};
}
