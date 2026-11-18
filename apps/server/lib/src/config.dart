import 'dart:io';

final class ServerConfig {
  const ServerConfig({
    this.host = '0.0.0.0',
    this.port = 8080,
    this.databaseHost = 'localhost',
    this.databasePort = 5432,
    this.databaseName = 'carwash',
    this.databaseUser = 'carwash',
    this.databasePassword = 'carwash_dev',
    this.sessionTtl = const Duration(hours: 1),
    this.allowedOrigins = const ['http://localhost:3000'],
    this.cookieSecure = false,
    this.demoPassword = 'DemoPass123!',
    this.migrationsPath = 'database/migrations',
  });

  factory ServerConfig.fromEnvironment(Map<String, String> env) {
    int number(String key, int fallback) {
      final value = int.tryParse(env[key] ?? '$fallback');
      if (value == null || value <= 0) throw FormatException('Invalid configuration: $key.');
      return value;
    }

    return ServerConfig(
      host: env['SERVER_HOST'] ?? '0.0.0.0',
      port: number('SERVER_PORT', 8080),
      databaseHost: env['DATABASE_HOST'] ?? 'localhost',
      databasePort: number('DATABASE_PORT', 5432),
      databaseName: env['POSTGRES_DB'] ?? 'carwash',
      databaseUser: env['POSTGRES_USER'] ?? 'carwash',
      databasePassword: env['POSTGRES_PASSWORD'] ?? 'carwash_dev',
      sessionTtl: Duration(seconds: number('SESSION_TTL_SECONDS', 3600)),
      allowedOrigins: (env['CORS_ALLOWED_ORIGINS'] ?? 'http://localhost:3000')
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      cookieSecure: env['COOKIE_SECURE'] == 'true',
      demoPassword: env['DEMO_PASSWORD'] ?? 'DemoPass123!',
      migrationsPath: env['MIGRATIONS_PATH'] ?? 'database/migrations',
    );
  }

  final String host;
  final int port;
  final String databaseHost;
  final int databasePort;
  final String databaseName;
  final String databaseUser;
  final String databasePassword;
  final Duration sessionTtl;
  final List<String> allowedOrigins;
  final bool cookieSecure;
  final String demoPassword;
  final String migrationsPath;
}

Future<Map<String, String>> serverEnvironment() async {
  final values = <String, String>{};
  final file = File('.env');
  if (await file.exists()) {
    for (final line in await file.readAsLines()) {
      final text = line.trim();
      if (text.isEmpty || text.startsWith('#')) continue;
      final equals = text.indexOf('=');
      if (equals < 1) throw const FormatException('Invalid .env entry.');
      var value = text.substring(equals + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      values[text.substring(0, equals).trim()] = value;
    }
  }
  return {...values, ...Platform.environment};
}
