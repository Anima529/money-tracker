import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_dates.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/providers/transaction_providers.dart';

/// 定期检查本地月份，跨月后让首页订阅新的月度账单。
final currentMonthProvider = StreamProvider<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  var month = AppDates.monthStart(DateTime.now());
  controller.add(month);
  final timer = Timer.periodic(const Duration(seconds: 30), (_) {
    final next = AppDates.monthStart(DateTime.now());
    if (next != month) {
      month = next;
      controller.add(month);
    }
  });
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

/// 月度收支只统计已确认的收入和支出，不包含转账。
class MonthlySummary {
  const MonthlySummary({required this.income, required this.expense});
  factory MonthlySummary.fromTransactions(List<Transaction> transactions) {
    var income = 0;
    var expense = 0;
    for (final transaction in transactions) {
      if (transaction.status != TransactionStatus.confirmed) continue;
      if (transaction.type == TransactionType.income) {
        income += transaction.amount;
      } else if (transaction.type == TransactionType.expense) {
        expense += transaction.amount;
      }
    }
    return MonthlySummary(income: income, expense: expense);
  }

  /// 已确认收入合计，单位为分。
  final int income;

  /// 已确认支出合计，单位为分。
  final int expense;

  /// 收入减支出，单位为分。
  int get balance => income - expense;
}

final monthlySummaryProvider =
    Provider.family<AsyncValue<MonthlySummary>, DateTime>(
      (ref, month) => ref
          .watch(monthlyTransactionsProvider(month))
          .whenData(MonthlySummary.fromTransactions),
    );
