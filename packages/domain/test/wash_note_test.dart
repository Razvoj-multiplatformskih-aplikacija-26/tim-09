import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('R1 · napomena', () {
    test('300 znakova prolazi', () {
      expect(WashNote.parse('a' * 300).isSuccess, isTrue);
    });

    test('301 znak pada sa NoteTooLong', () {
      expect(WashNote.parse('a' * 301).errorOrNull, const NoteTooLong(301));
    });

    test('razmaci na krajevima se ne broje', () {
      expect(WashNote.parse('  ${'a' * 300}  ').isSuccess, isTrue);
    });
  });
}
