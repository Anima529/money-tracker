import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/utils/money.dart';

void main() {
  test('decimal input converts to exact integer cents', () {
    expect(Money.parseCents('12.50'), 1250);
    expect(Money.parseCents('0.01'), 1);
    expect(Money.parseCents(' 12.5 '), 1250);
    expect(Money.parseCents('0'), 0);
    expect(Money.parseCents('9999999999.99'), Money.maxCents);
  });
  test('invalid and overflowing input is rejected', () {
    for (final value in [
      '',
      '-1',
      '1.001',
      'NaN',
      '1e3',
      '1,000',
      '.5',
      '10000000000',
      '999999999999999999999',
    ]) {
      expect(
        () => Money.parseCents(value),
        throwsFormatException,
        reason: value,
      );
    }
  });
  test('formatting preserves cents and grouping', () {
    expect(Money.format(1250), '¥12.50');
    expect(Money.format(1), '¥0.01');
    expect(Money.format(0), '¥0.00');
    expect(Money.format(-123456), '−¥1,234.56');
    expect(Money.format(Money.maxCents, symbol: false), '9,999,999,999.99');
  });
}
