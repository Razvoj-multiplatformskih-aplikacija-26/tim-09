import 'package:postgres/postgres.dart';

import '../config.dart';

Pool<void> openDatabase(ServerConfig config) => Pool<void>.withEndpoints(
  [
    Endpoint(
      host: config.databaseHost,
      port: config.databasePort,
      database: config.databaseName,
      username: config.databaseUser,
      password: config.databasePassword,
    ),
  ],
  settings: const PoolSettings(
    sslMode: SslMode.disable,
    maxConnectionCount: 8,
    ignoreSuperfluousParameters: true,
    connectTimeout: Duration(seconds: 10),
    queryTimeout: Duration(seconds: 15),
  ),
);
