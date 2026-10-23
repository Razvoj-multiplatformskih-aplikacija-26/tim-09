import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('R2 · registarska oznaka', () {
    test('prihvata BG 123-AB i NS 4521-ČŠ', () {
      expect(LicensePlate.parse('BG 123-AB').isSuccess, isTrue);
      expect(LicensePlate.parse('NS 4521-ČŠ').isSuccess, isTrue);
    });

    test('mala slova i višak razmaka se ispravljaju', () {
      expect(LicensePlate.parse('  bg   123-ab ').valueOrNull?.value, 'BG 123-AB');
    });

    test('pogrešan format pada sa InvalidLicensePlate', () {
      for (final input in ['', 'BG123AB', 'B 123-AB', 'BG 12-AB', 'BG 123-A']) {
        expect(LicensePlate.parse(input).errorOrNull, isA<InvalidLicensePlate>(), reason: input);
      }
    });
  });
}
