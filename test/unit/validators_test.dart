import 'package:flutter_test/flutter_test.dart';
import 'package:ndid_mobile/services/validators.dart';

void main() {
  group('isValidThaiCitizenId', () {
    test('accepts an id with a correct check digit', () {
      expect(isValidThaiCitizenId('1101700230678'), isTrue);
    });

    test('rejects a wrong check digit, wrong length and non-digits', () {
      expect(isValidThaiCitizenId('1101700230673'), isFalse);
      expect(isValidThaiCitizenId('110170023067'), isFalse);
      expect(isValidThaiCitizenId('11017002306a3'), isFalse);
    });
  });

  test('validateThaiPhone accepts mobile prefixes only', () {
    expect(validateThaiPhone('0812345678'), isNull);
    expect(validateThaiPhone('0212345678'), isNotNull);
    expect(validateThaiPhone('081234567'), isNotNull);
    expect(validateThaiPhone(''), isNotNull);
  });

  test('validateEmail requires a domain', () {
    expect(validateEmail('test@example.com'), isNull);
    expect(validateEmail('test@example'), isNotNull);
    expect(validateEmail(''), isNotNull);
  });
}
