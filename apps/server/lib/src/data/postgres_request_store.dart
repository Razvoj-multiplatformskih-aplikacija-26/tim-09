import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import '../ports/request_store.dart';
import 'request_row_mapper.dart';

final class PostgresRequestStore implements RequestStore {
  const PostgresRequestStore(this.database);

  final Pool<void> database;

  @override
  Future<T> transaction<T>(Future<T> Function(RequestTransaction transaction) action) =>
      database.runTx((session) => action(_RequestTransaction(session)));

  @override
  Future<WashRequest?> find(WashRequestId id) async {
    final rows = await database.execute(
      Sql.named('SELECT * FROM wash_requests WHERE id = @id'),
      parameters: {'id': id.value},
    );
    return rows.isEmpty ? null : requestFromRow(rows.single.toColumnMap());
  }

  @override
  Future<RequestPage> list({
    UserId? clientId,
    WasherId? washerId,
    String? status,
    required int limit,
    required int offset,
  }) async {
    final conditions = <String>[];
    final parameters = <String, Object?>{'limit': limit, 'offset': offset};
    if (clientId != null) {
      conditions.add('client_id = @clientId');
      parameters['clientId'] = clientId.value;
    }
    if (washerId != null) {
      conditions.add("washer_id = @washerId AND status IN ('accepted', 'in_progress')");
      parameters['washerId'] = washerId.value;
    }
    if (status != null) {
      conditions.add('status = @status');
      parameters['status'] = status;
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    return database.runTx((session) async {
      final count = await session.execute(
        Sql.named('SELECT COUNT(*) FROM wash_requests $where'),
        parameters: parameters,
      );
      final rows = await session.execute(
        Sql.named('SELECT * FROM wash_requests $where ORDER BY start_at, id LIMIT @limit OFFSET @offset'),
        parameters: parameters,
      );
      return RequestPage(
        items: rows.map((row) => requestFromRow(row.toColumnMap())).toList(),
        total: count.single.single as int,
        limit: limit,
        offset: offset,
      );
    }, settings: TransactionSettings(isolationLevel: IsolationLevel.repeatableRead));
  }

  @override
  Future<List<WashRequest>> activeJobs() => _activeJobs(database);

  @override
  Future<List<({WasherId id, String name})>> washers() async {
    final rows = await database.execute('SELECT id, name FROM washers ORDER BY name');
    return rows.map((row) => (id: WasherId(row[0] as String), name: row[1] as String)).toList();
  }
}

Future<List<WashRequest>> _activeJobs(Session session) async {
  final rows = await session.execute("SELECT * FROM wash_requests WHERE status IN ('accepted', 'in_progress')");
  return rows.map((row) => requestFromRow(row.toColumnMap())).toList();
}

final class _RequestTransaction implements RequestTransaction {
  const _RequestTransaction(this.session);

  final TxSession session;

  @override
  Future<void> lockClient(UserId id) =>
      session.execute(Sql.named('SELECT id FROM users WHERE id = @id FOR UPDATE'), parameters: {'id': id.value});

  @override
  Future<bool> lockWasher(WasherId id) async {
    final rows = await session.execute(
      Sql.named('SELECT id FROM washers WHERE id = @id FOR UPDATE'),
      parameters: {'id': id.value},
    );
    return rows.isNotEmpty;
  }

  @override
  Future<WashRequest?> lockRequest(WashRequestId id) async {
    final rows = await session.execute(
      Sql.named('SELECT * FROM wash_requests WHERE id = @id FOR UPDATE'),
      parameters: {'id': id.value},
    );
    return rows.isEmpty ? null : requestFromRow(rows.single.toColumnMap());
  }

  @override
  Future<List<WashRequest>> requestsOf(UserId clientId) async {
    final rows = await session.execute(
      Sql.named('SELECT * FROM wash_requests WHERE client_id = @id'),
      parameters: {'id': clientId.value},
    );
    return rows.map((row) => requestFromRow(row.toColumnMap())).toList();
  }

  @override
  Future<List<WashRequest>> activeJobs() => _activeJobs(session);

  @override
  Future<void> insert(WashRequest request, {double? latitude, double? longitude}) =>
      insertRequest(session, request, latitude: latitude, longitude: longitude);

  @override
  Future<void> update(WashRequest request) async {
    await session.execute(
      Sql.named('''
      UPDATE wash_requests SET
        status = @status, washer_id = @washerId, accepted_by = @acceptedBy, accepted_at = @acceptedAt,
        arrived_at = @arrivedAt, finished_at = @finishedAt, cancel_reason = @cancelReason,
        cancelled_by = @cancelledBy, cancelled_at = @cancelledAt
      WHERE id = @id
    '''),
      parameters: completeRequestParameters(request),
    );
  }
}

Future<void> insertRequest(Session session, WashRequest request, {double? latitude, double? longitude}) async {
  await session.execute(
    Sql.named('''
      INSERT INTO wash_requests (
        id, client_id, vehicle_type, plate, tier, address, start_at, duration_minutes, note, created_at, status,
        washer_id, accepted_by, accepted_at, arrived_at, finished_at, cancel_reason, cancelled_by, cancelled_at,
        latitude, longitude
      ) VALUES (
        @id, @clientId, @vehicleType, @plate, @tier, @address, @start, @duration, @note, @createdAt, @status,
        @washerId, @acceptedBy, @acceptedAt, @arrivedAt, @finishedAt, @cancelReason, @cancelledBy, @cancelledAt,
        @latitude, @longitude
      )
    '''),
    parameters: {...completeRequestParameters(request), 'latitude': latitude, 'longitude': longitude},
  );
}
