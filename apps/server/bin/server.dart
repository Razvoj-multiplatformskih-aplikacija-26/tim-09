import 'dart:async';
import 'dart:io';

import 'package:relic/io_adapter.dart';
import 'package:server/server.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--health')) {
    await healthCheck();
    return;
  }
  final config = ServerConfig.fromEnvironment(await serverEnvironment());
  final database = openDatabase(config);
  try {
    await bootstrap(database, config);
    final app = ServerApp(
      auth: AuthService(database: database, config: config),
      requests: RequestService(store: PostgresRequestStore(database)),
      config: config,
    ).build();
    final server = await app.serve(address: InternetAddress(config.host), port: config.port);
    stdout.writeln('CarWash & Go server: ${config.host}:${server.port}');
    final signal = Completer<void>();
    final subscriptions = [
      ProcessSignal.sigint.watch().listen((_) {
        if (!signal.isCompleted) signal.complete();
      }),
      ProcessSignal.sigterm.watch().listen((_) {
        if (!signal.isCompleted) signal.complete();
      }),
    ];
    await signal.future;
    await server.close();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  } finally {
    await database.close();
  }
}

Future<void> healthCheck() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    final port = Platform.environment['SERVER_PORT'] ?? '8080';
    final request = await client.getUrl(Uri.parse('http://127.0.0.1:$port/health'));
    final response = await request.close().timeout(const Duration(seconds: 3));
    await response.drain<void>();
    exitCode = response.statusCode == 200 ? 0 : 1;
  } on Exception {
    exitCode = 1;
  } finally {
    client.close(force: true);
  }
}
