import 'dart:convert';
import 'dart:io' as io;

import 'package:api_mapping/api_mapping.dart';
import 'package:contracts/contracts.dart';
import 'package:domain/domain.dart' as domain;
import 'package:relic/relic.dart';

import 'api_exception.dart';
import 'config.dart';
import 'services/auth_service.dart';
import 'services/request_service.dart';

final class ServerApp {
  const ServerApp({required this.auth, required this.requests, required this.config});

  final AuthService auth;
  final RequestService requests;
  final ServerConfig config;

  RelicApp build() => RelicApp()
    ..use('/', _middleware)
    ..options('/requests', (_) => Response(204))
    ..options('/requests/:id', (_) => Response(204))
    ..options('/requests/:id/:action', (_) => Response(204))
    ..options('/auth/:action', (_) => Response(204))
    ..options('/washers', (_) => Response(204))
    ..get('/health', _health)
    ..post('/auth/login', _login)
    ..get('/auth/me', _protected(_me))
    ..post('/auth/logout', _protected(_logout))
    ..get('/requests', _protected(_list))
    ..get('/requests/:id', _protected(_find))
    ..post('/requests', _protected(_create))
    ..post('/requests/:id/cancel', _protected(_cancel))
    ..post('/requests/:id/assign', _protected(_assign))
    ..post('/requests/:id/release', _protected(_release))
    ..get('/washers', _protected(_washers))
    ..fallback = (_) => _json(404, ApiError(code: 'not_found').toJson());

  Handler _middleware(Handler next) => (request) async {
    final origin = request.headers['origin']?.firstOrNull;
    Response response;
    try {
      if (origin != null && !config.allowedOrigins.contains(origin)) throw ApiException(403, 'not_allowed');
      if (request.method == Method.options) {
        response = Response(204);
      } else {
        final result = await next(request);
        if (result is! Response) return result;
        response = result;
      }
    } on ApiException catch (error) {
      response = _json(error.status, error.error.toJson());
      if (error.status == 401 && request.headers['cookie'] != null) {
        response = _withCookie(response, _cookie('', delete: true));
      }
    } on MaxBodySizeExceeded {
      response = _json(400, ApiError(code: 'invalid_request').toJson());
    } on FormatException {
      response = _json(400, ApiError(code: 'invalid_request').toJson());
    } catch (error, stack) {
      io.stderr.writeln('$error\n$stack');
      response = _json(500, ApiError(code: 'server_error').toJson());
    }
    return response.copyWith(
      headers: response.headers.transform((headers) {
        headers['Cache-Control'] = ['no-store'];
        if (origin != null && config.allowedOrigins.contains(origin)) {
          headers['Access-Control-Allow-Origin'] = [origin];
          headers['Access-Control-Allow-Credentials'] = ['true'];
          headers['Access-Control-Allow-Methods'] = ['GET, POST, OPTIONS'];
          headers['Access-Control-Allow-Headers'] = ['Content-Type, Authorization'];
          headers['Vary'] = ['Origin'];
        }
      }),
    );
  };

  Handler _protected(Future<Response> Function(Request request, ServerSession session) handler) =>
      (request) async => handler(request, await _session(request));

  Future<ServerSession> _session(Request request) {
    final authorization = request.headers['authorization']?.firstOrNull;
    final cookieParts = request.headers['cookie']?.join(';').split(';') ?? [];
    final cookies = cookieParts
        .map((part) => part.trim())
        .where((part) => part.startsWith('carwash_session='))
        .toList();
    if (cookies.length > 1 || (authorization != null && cookies.isNotEmpty)) {
      throw ApiException(400, 'invalid_request');
    }
    if (authorization != null) {
      if (!authorization.startsWith('Bearer ') || authorization.length <= 7) throw ApiException(401, 'unauthenticated');
      return auth.authenticate(authorization.substring(7), 'bearer');
    }
    if (cookies.isEmpty) throw ApiException(401, 'unauthenticated');
    if (request.method != Method.get && request.method != Method.head) _checkCookieOrigin(request);
    final token = cookies.single.substring('carwash_session='.length);
    return auth.authenticate(token, 'cookie');
  }

  void _checkCookieOrigin(Request request) {
    final origin = request.headers['origin']?.firstOrNull;
    if (origin == null || !config.allowedOrigins.contains(origin)) throw ApiException(403, 'not_allowed');
  }

  Future<Map<String, Object?>> _body(Request request) async =>
      jsonObject(jsonDecode(await request.readAsString(maxLength: 65536)));

  Future<Response> _health(Request request) async {
    await auth.database.execute('SELECT 1');
    return _json(200, {'status': 'ok'});
  }

  Future<Response> _login(Request request) async {
    final input = LoginRequest.fromJson(await _body(request));
    if (input.sessionTransport == 'cookie') _checkCookieOrigin(request);
    final result = await auth.login(input);
    final response = _json(200, result.dto.toJson());
    return input.sessionTransport == 'cookie' ? _withCookie(response, _cookie(result.token)) : response;
  }

  Future<Response> _me(Request request, ServerSession session) async => _json(200, session.dto.toJson());

  Future<Response> _logout(Request request, ServerSession session) async {
    await auth.logout(session);
    final response = Response(204);
    return session.transport == 'cookie' ? _withCookie(response, _cookie('', delete: true)) : response;
  }

  Future<Response> _list(Request request, ServerSession session) async {
    final query = request.url.queryParameters;
    final scope = query['scope'] ?? 'mine';
    final limit = int.tryParse(query['limit'] ?? '20');
    final offset = int.tryParse(query['offset'] ?? '0');
    final status = query['status'];
    if (limit == null ||
        limit < 1 ||
        limit > 100 ||
        offset == null ||
        offset < 0 ||
        !{'mine', 'all'}.contains(scope) ||
        (status != null && !{'submitted', 'accepted', 'in_progress', 'completed', 'cancelled'}.contains(status))) {
      throw ApiException(400, 'invalid_request');
    }
    final user = session.user;
    if (scope == 'all' && !domain.mayViewAllRequests(user)) throw ApiException(403, 'not_allowed');
    if (scope == 'mine' && user.role == domain.Role.dispatcher) throw ApiException(403, 'not_allowed');
    if (user.role == domain.Role.washer && user.washerId == null) throw ApiException(403, 'not_allowed');
    final page = await requests.store.list(
      clientId: user.role == domain.Role.client ? user.id : null,
      washerId: user.role == domain.Role.washer ? user.washerId : null,
      status: status,
      limit: limit,
      offset: offset,
    );
    return _json(
      200,
      RequestPageDto(
        items: page.items.map(requestToDto).toList(),
        total: page.total,
        limit: page.limit,
        offset: page.offset,
      ).toJson(),
    );
  }

  domain.WashRequestId _id(Request request) => domain.WashRequestId(request.pathParameters.raw[#id]!);

  Future<Response> _find(Request request, ServerSession session) async =>
      _result(await requests.find(_id(request), session.user));

  Future<Response> _create(Request request, ServerSession session) async =>
      _result(await requests.create(CreateRequest.fromJson(await _body(request)), session.user), successStatus: 201);

  Future<Response> _assign(Request request, ServerSession session) async {
    final input = AssignRequest.fromJson(await _body(request));
    return _result(await requests.assign(_id(request), domain.WasherId(input.washerId), session.user));
  }

  Future<Response> _cancel(Request request, ServerSession session) async {
    final input = CancelRequestDto.fromJson(await _body(request));
    return _result(await requests.cancel(_id(request), input.reason, session.user));
  }

  Future<Response> _release(Request request, ServerSession session) async {
    jsonFields(await _body(request), {});
    return _result(await requests.release(_id(request), session.user));
  }

  Future<Response> _washers(Request request, ServerSession session) async {
    if (!domain.mayAssignRequest(session.user)) throw ApiException(403, 'not_allowed');
    final washers = await requests.washers(session.user);
    return _json(200, {'items': washers.map((washer) => washerToDto(washer).toJson()).toList()});
  }

  Response _result(domain.Result<domain.WashRequest> result, {int successStatus = 200}) => switch (result) {
    domain.Success(:final value) => _json(successStatus, RequestResponse(requestToDto(value)).toJson()),
    domain.Failure(:final error) => _json(errorStatus(error), errorToDto(error).toJson()),
  };

  String _cookie(String value, {bool delete = false}) =>
      (io.Cookie('carwash_session', value)
            ..httpOnly = true
            ..secure = config.cookieSecure
            ..sameSite = io.SameSite.lax
            ..path = '/'
            ..maxAge = delete ? 0 : config.sessionTtl.inSeconds)
          .toString();

  Response _withCookie(Response response, String cookie) =>
      response.copyWith(headers: response.headers.transform((headers) => headers['Set-Cookie'] = [cookie]));

  Response _json(int status, Map<String, Object?> value) =>
      Response(status, body: Body.fromString(jsonEncode(value), mimeType: MimeType.json));
}
