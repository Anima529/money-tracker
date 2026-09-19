import 'package:intl/intl.dart';

abstract final class Money {
  /// 数据库允许的最大金额，单位为分。
  static const maxCents = 999999999999;

  static int parseCents(String input) {
    final value = input.trim();
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) {
      throw const FormatException('请输入最多两位小数的非负金额');
    }
    final parts = value.split('.');
    // 用 BigInt 校验超长输入，整个换算过程不经过浮点数。
    final cents =
        BigInt.parse(parts.first) * BigInt.from(100) +
        BigInt.parse(parts.length == 2 ? parts[1].padRight(2, '0') : '00');
    if (cents > BigInt.from(maxCents)) {
      throw const FormatException('金额超出支持范围');
    }
    return cents.toInt();
  }

  /// 将整数分格式化为人民币文本，不经过浮点数。
  static String format(int cents, {bool symbol = true}) {
    final absolute = cents.abs();
    final whole = NumberFormat.decimalPattern('zh_CN').format(absolute ~/ 100);
    final fraction = (absolute % 100).toString().padLeft(2, '0');
    return '${cents < 0 ? '−' : ''}${symbol ? '¥' : ''}$whole.$fraction';
  }
}
