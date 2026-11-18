import 'dart:async';
import 'dart:convert';

import 'package:contracts/contracts.dart';
import 'package:http/http.dart' as http;
import 'package:use_cases/use_cases.dart';

import 'session_controller.dart';

sealed class ApiResult {
  const ApiResult(this.status);

  final int status;
}

final class ApiOk extends ApiResult {
  const ApiOk(super.status, this.json);

  final Object? json;
}

final class ApiRejected extends ApiResult {
  const ApiRejected(super.status, this.error);

  final ApiError error;
}

final class CarWashApi {
  CarWashApi({
    required this.baseUrl,
    required this.client,
    required this.session,
    this.timeout = const Duration(seconds: 10),
  });

  static const _businessStatuses = {403, 404, 409, 422};

  final Uri baseUrl;
  final http.Client client;
  final SessionController session;
  final Duration timeout;

  Future<ApiResult> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
    bool reportsExpiry = true,
  }) => _send('GET', path, query: query, authenticated: authenticated, reportsExpiry: reportsExpiry);

  Future<ApiResult> post(String path, {Object? body, bool authenticated = true, bool reportsExpiry = true}) =>
      _send('POST', path, body: body, authenticated: authenticated, reportsExpiry: reportsExpiry);

  Uri _uri(String path, Map<String, String>? query) {
    final base = baseUrl.path.endsWith('/') ? baseUrl.path.substring(0, baseUrl.path.length - 1) : baseUrl.path;
    return baseUrl.replace(path: '$base$path', queryParameters: query == null || query.isEmpty ? null : query);
  }

  Future<ApiResult> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    required bool authenticated,
    required bool reportsExpiry,
  }) async {
    final generation = session.generation;
    final request = http.Request(method, _uri(path, query))..headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final authorization = session.authorization;
    if (authenticated && authorization != null) request.headers['Authorization'] = authorization;
    final writes = method != 'GET';
    final http.Response response;
    try {
      response = await client.send(request).then(http.Response.fromStream).timeout(timeout);
    } on TimeoutException catch (cause) {
      throw NetworkException('No response within $timeout.', timedOut: true, outcomeUnknown: writes, cause: cause);
    } on http.ClientException catch (cause) {
      throw NetworkException('Server is not reachable.', outcomeUnknown: writes, cause: cause);
    }
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      if (status == 204 || response.bodyBytes.isEmpty) return ApiOk(status, null);
      return ApiOk(status, _decode(response));
    }
    final error = _error(response);
    if (status == 401) {
      if (authenticated && reportsExpiry) {
        session.expire(generation);
        throw const SessionExpiredException();
      }
      if (error != null) return ApiRejected(status, error);
    }
    if (error != null && _businessStatuses.contains(status)) return ApiRejected(status, error);
    throw ProtocolException('Unexpected response ${error?.code ?? ''}'.trim(), statusCode: status);
  }

  Object? _decode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (cause) {
      throw ProtocolException('Unreadable response.', statusCode: response.statusCode, cause: cause);
    }
  }

  ApiError? _error(http.Response response) {
    try {
      return ApiError.fromJson(jsonObject(jsonDecode(utf8.decode(response.bodyBytes))));
    } on FormatException {
      return null;
    }
  }
}

T readContract<T>(Object? json, T Function(Map<String, Object?> json) read) {
  try {
    return read(jsonObject(json));
  } on FormatException catch (cause) {
    throw ProtocolException('Response does not match the contract.', cause: cause);
  }
}
