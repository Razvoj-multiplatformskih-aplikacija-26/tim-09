import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_adapters/platform_adapters.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('token se upisuje, čita posle ponovnog otvaranja i briše', () async {
    await SecureSessionStorage().write('secret-token');
    expect(await SecureSessionStorage().read(), 'secret-token');
    await SecureSessionStorage().delete();
    expect(await SecureSessionStorage().read(), isNull);
  });

  test('opis skladišta ne otkriva token', () async {
    final storage = SecureSessionStorage();
    await storage.write('secret-token');
    expect(storage.toString(), isNot(contains('secret-token')));
  });
}
