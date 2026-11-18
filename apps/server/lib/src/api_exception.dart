import 'package:contracts/contracts.dart';

final class ApiException implements Exception {
  ApiException(this.status, String code, [Map<String, Object?> details = const {}])
    : error = ApiError(code: code, details: details);

  final int status;
  final ApiError error;
}
