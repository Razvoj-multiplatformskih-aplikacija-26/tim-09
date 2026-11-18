import 'package:api_mapping/api_mapping.dart';
import 'package:contracts/contracts.dart';
import 'package:domain/domain.dart';
import 'package:use_cases/use_cases.dart';

import 'car_wash_api.dart';

final class HttpWashRequestRepository implements WashRequestRepository {
  const HttpWashRequestRepository(this.api);

  final CarWashApi api;

  String _path(WashRequestId id, [String action = '']) =>
      '/requests/${Uri.encodeComponent(id.value)}${action.isEmpty ? '' : '/$action'}';

  @override
  Future<RequestPage> list(RequestQuery query) async {
    final result = await api.get('/requests', query: queryToDto(query));
    return switch (result) {
      ApiOk(:final json) => readContract(json, (json) => requestPageFromDto(RequestPageDto.fromJson(json))),
      ApiRejected(:final status, :final error) => throw ProtocolException(error.code, statusCode: status),
    };
  }

  @override
  Future<WashRequest?> find(WashRequestId id) async {
    final result = await api.get(_path(id));
    return switch (result) {
      ApiOk(:final json) => _request(json),
      ApiRejected(error: ApiError(code: 'not_found' || 'not_allowed')) => null,
      ApiRejected(:final status, :final error) => throw ProtocolException(error.code, statusCode: status),
    };
  }

  @override
  Future<Result<WashRequest>> create(WashRequestDraft draft) async =>
      _command(await api.post('/requests', body: draftToDto(draft).toJson()));

  @override
  Future<Result<WashRequest>> cancel({required WashRequestId id, required String reason}) async =>
      _command(await api.post(_path(id, 'cancel'), body: CancelRequestDto(reason: reason).toJson()));

  @override
  Future<Result<WashRequest>> assign({required WashRequestId id, required WasherId washerId}) async =>
      _command(await api.post(_path(id, 'assign'), body: AssignRequest(washerId: washerId.value).toJson()));

  @override
  Future<Result<WashRequest>> release({required WashRequestId id}) async =>
      _command(await api.post(_path(id, 'release'), body: const <String, Object?>{}));

  WashRequest _request(Object? json) =>
      readContract(json, (json) => requestFromDto(RequestResponse.fromJson(json).request));

  Result<WashRequest> _command(ApiResult result) => switch (result) {
    ApiOk(:final json) => Success(_request(json)),
    ApiRejected(:final error) => Failure(errorFromDto(error)),
  };
}
