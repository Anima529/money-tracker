import 'money.dart';

/// 只支持正数金额之间的加减，所有中间值都以整数分计算。
abstract final class AmountExpression {
  static int evaluate(String input) {
    final expression = input.replaceAll(RegExp(r'\s+'), '');
    if (expression.isEmpty ||
        !RegExp(r'^\d+(?:\.\d{0,2})?(?:[+-]\d+(?:\.\d{0,2})?)*$')
            .hasMatch(expression)) {
      throw const FormatException('请输入有效金额');
    }

    final tokens = RegExp(r'([+-]?)(\d+(?:\.\d{0,2})?)').allMatches(expression);
    var total = BigInt.zero;
    for (final token in tokens) {
      final cents = BigInt.from(Money.parseCents(token.group(2)!));
      total += token.group(1) == '-' ? -cents : cents;
      if (total.abs() > BigInt.from(Money.maxCents)) {
        throw const FormatException('金额超出支持范围');
      }
    }
    if (total <= BigInt.zero) {
      throw const FormatException('金额必须大于 0');
    }
    return total.toInt();
  }

  /// 编辑器中的预览允许末尾暂时停留在运算符或小数点。
  static int? preview(String input) {
    final normalized = input.endsWith('+') || input.endsWith('-')
        ? input.substring(0, input.length - 1)
        : input.endsWith('.')
        ? '${input}0'
        : input;
    try {
      return evaluate(normalized);
    } on FormatException {
      return null;
    }
  }
}
