import 'package:flutter/material.dart';

abstract final class AppColors {
  /// Material 3 配色种子。
  static const seed = Color(0xFF486A61);

  /// 浅色模式收入色。
  static const income = Color(0xFF357C66);

  /// 浅色模式支出色。
  static const expense = Color(0xFFA56552);

  /// 深色模式收入色。
  static const darkIncome = Color(0xFF94CBB4);

  /// 深色模式支出色。
  static const darkExpense = Color(0xFFE0AF9C);
  static Color transaction(BuildContext context, {required bool income}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return income
        ? (dark ? darkIncome : AppColors.income)
        : (dark ? darkExpense : expense);
  }
}
