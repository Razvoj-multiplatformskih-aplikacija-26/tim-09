import 'dart:io';
import 'dart:isolate';

import 'package:bcrypt/bcrypt.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import 'config.dart';
import 'data/postgres_request_store.dart';

Future<void> bootstrap(Pool<void> database, ServerConfig config, {DateTime? now}) async {
  await migrate(database, config.migrationsPath);
  await seed(database, config.demoPassword, now: now ?? DateTime.now().toUtc());
}

Future<void> migrate(Pool<void> database, String migrationsPath) async {
  final files = await Directory(migrationsPath).list().where((entry) => entry.path.endsWith('.sql')).toList();
  files.sort((a, b) => a.path.compareTo(b.path));
  await database.runTx((session) async {
    await session.execute('SELECT pg_advisory_xact_lock(90902)');
    await session.execute('CREATE TABLE IF NOT EXISTS schema_migrations (name TEXT PRIMARY KEY)');
    for (final entry in files) {
      final name = entry.uri.pathSegments.last;
      final existing = await session.execute(
        Sql.named('SELECT name FROM schema_migrations WHERE name = @name'),
        parameters: {'name': name},
      );
      if (existing.isNotEmpty) continue;
      await session.execute(await File(entry.path).readAsString(), queryMode: QueryMode.simple);
      await session.execute(
        Sql.named('INSERT INTO schema_migrations (name) VALUES (@name)'),
        parameters: {'name': name},
      );
    }
  });
}

Future<void> seed(Pool<void> database, String password, {required DateTime now}) async {
  final hash = await Isolate.run(() => BCrypt.hashpw(password, BCrypt.gensalt()));
  await database.runTx((session) async {
    await session.execute('SELECT pg_advisory_xact_lock(90903)');
    final users = [
      ('u-client', 'marko', 'client'),
      ('u-other', 'ana', 'client'),
      ('u-dispatcher', 'dispecer', 'dispatcher'),
      ('u-washer-1', 'nikola', 'washer'),
      ('u-washer-2', 'jovan', 'washer'),
      ('u-washer-3', 'stefan', 'washer'),
    ];
    for (final (id, username, role) in users) {
      await session.execute(
        Sql.named('''
        INSERT INTO users (id, username, password_hash, role) VALUES (@id, @username, @hash, @role)
        ON CONFLICT (id) DO NOTHING
      '''),
        parameters: {'id': id, 'username': username, 'hash': hash, 'role': role},
      );
    }
    for (final (id, userId, name) in [
      ('w-1', 'u-washer-1', 'Nikola Petrović'),
      ('w-2', 'u-washer-2', 'Jovan Ilić'),
      ('w-3', 'u-washer-3', 'Stefan Marković'),
    ]) {
      await session.execute(
        Sql.named('''
        INSERT INTO washers (id, user_id, name) VALUES (@id, @userId, @name) ON CONFLICT (id) DO NOTHING
      '''),
        parameters: {'id': id, 'userId': userId, 'name': name},
      );
    }
    final existing = await session.execute("SELECT id FROM wash_requests WHERE id = 'seed-1'");
    if (existing.isNotEmpty) return;
    final local = inBusinessTime(now);
    final tomorrow = businessDate(local.year, local.month, local.day + 1, 10);
    final activeDay = local.hour < 8 ? local.day - 1 : local.day;
    final activeHour = local.hour < 8 ? 18 : local.hour.clamp(8, 18);
    final activeMinute = local.hour < 8 || local.hour > 18 ? 30 : local.minute ~/ 30 * 30;
    final activeStart = businessDate(local.year, local.month, activeDay, activeHour, activeMinute);
    for (var i = 0; i < 12; i++) {
      final clientId = UserId(i.isEven ? 'u-client' : 'u-other');
      final tier = i.isEven ? ServiceTier.economy : ServiceTier.professional;
      final duration = estimate(VehicleType.sedan, tier).duration;
      final start = switch (i) {
        < 3 => tomorrow.add(Duration(minutes: i * 30)),
        3 => activeStart,
        _ => businessDate(local.year, local.month, local.day - (i - 3), 10),
      };
      final WashStatus status = switch (i) {
        0 || 1 => const Submitted(),
        2 => Accepted(washerId: const WasherId('w-2'), acceptedBy: const UserId('u-dispatcher'), at: now),
        3 => InProgress(washerId: const WasherId('w-3'), arrivedAt: now),
        < 8 => Completed(finishedAt: start.add(duration)),
        _ => Cancelled(reason: 'Promena plana.', cancelledBy: clientId, at: start.subtract(const Duration(hours: 2))),
      };
      final request = WashRequest(
        id: WashRequestId('seed-${i + 1}'),
        clientId: clientId,
        vehicle: Vehicle(type: VehicleType.sedan, plate: LicensePlate.existing('BG ${120 + i}-AB')),
        tier: tier,
        address: const Address.existing('Knez Mihailova 6, Beograd'),
        slot: WashSlot.existing(start, duration),
        createdAt: i < 3 ? now.subtract(const Duration(hours: 1)) : start.subtract(const Duration(days: 1)),
        status: status,
      );
      await insertRequest(session, request);
    }
  });
}
