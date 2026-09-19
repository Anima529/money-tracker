import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/utils/amount_expression.dart';

void main() {
  test('amount expression calculates with integer cents', () {
    expect(AmountExpression.evaluate('12.30+4.5-0.80'), 1600);
    expect(AmountExpression.evaluate('9999999999.99'), 999999999999);
    expect(AmountExpression.preview('20+'), 2000);
    expect(AmountExpression.preview('1.'), 100);
  });

  test(
    'amount expression rejects invalid, non-positive and overflow values',
    () {
      for (final value in [
        '',
        '0',
        '-1',
        '1-1',
        '1.234',
        '1*2',
        '10000000000',
      ]) {
        expect(() => AmountExpression.evaluate(value), throwsFormatException);
      }
      expect(AmountExpression.preview('1+'), 100);
      expect(AmountExpression.preview('abc'), isNull);
    },
  );
}
