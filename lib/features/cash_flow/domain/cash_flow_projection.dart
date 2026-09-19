import '../../../core/utils/app_dates.dart';
import '../../accounts/domain/account.dart';
import '../../schedules/domain/schedule_instance.dart';
import '../../transactions/domain/transaction.dart';

class CashFlowEvent {
  const CashFlowEvent({
    required this.date,
    required this.title,
    required this.type,
    required this.amount,
    required this.accountId,
    required this.transferAccountId,
    this.scheduleInstance,
    this.transaction,
    this.isEssential = false,
  });

  final DateTime date;
  final String title;
  final TransactionType type;
  final int amount;
  final int accountId;
  final int? transferAccountId;
  final ScheduleInstance? scheduleInstance;
  final Transaction? transaction;
  final bool isEssential;
}

class DailyBalancePoint {
  const DailyBalancePoint({
    required this.date,
    required this.totalBalance,
    required this.accountBalances,
    required this.events,
  });

  final DateTime date;
  final int totalBalance;
  final Map<int, int> accountBalances;
  final List<CashFlowEvent> events;
}

class CashFlowProjection {
  const CashFlowProjection({
    required this.points,
    required this.events,
    required this.minimumBalance,
    required this.minimumDate,
    required this.safeToSpend,
    required this.spendableBalance,
    required this.safetyBuffer,
    required this.reservedExpenses,
    required this.nextIncomeDate,
  });

  final List<DailyBalancePoint> points;
  final List<CashFlowEvent> events;
  final int minimumBalance;
  final DateTime minimumDate;
  final int safeToSpend;
  final int spendableBalance;
  final int safetyBuffer;
  final List<CashFlowEvent> reservedExpenses;
  final DateTime? nextIncomeDate;

  static CashFlowProjection calculate({
    required DateTime today,
    required List<AccountBalance> balances,
    required List<ScheduleInstance> scheduleInstances,
    required List<Transaction> plannedTransactions,
    required int safetyBuffer,
    int windowDays = 30,
  }) {
    final start = AppDates.dayStart(today);
    final through = DateTime(start.year, start.month, start.day + windowDays);
    final events =
        <CashFlowEvent>[
          for (final instance in scheduleInstances)
            CashFlowEvent(
              date: AppDates.dayStart(instance.scheduledFor),
              title: instance.schedule.title,
              type: instance.schedule.type,
              amount: instance.schedule.amount,
              accountId: instance.schedule.accountId,
              transferAccountId: instance.schedule.transferAccountId,
              scheduleInstance: instance,
              isEssential: instance.schedule.isEssential,
            ),
          for (final transaction in plannedTransactions)
            if (!transaction.transactionDate.isBefore(start) &&
                !transaction.transactionDate.isAfter(through))
              CashFlowEvent(
                date: AppDates.dayStart(transaction.transactionDate),
                title: transaction.note.isEmpty ? '一次性计划' : transaction.note,
                type: transaction.type,
                amount: transaction.amount,
                accountId: transaction.accountId,
                transferAccountId: transaction.transferAccountId,
                transaction: transaction,
                // 一次性手动计划没有必要性字段，保守地预留所有计划支出。
                isEssential: transaction.type == TransactionType.expense,
              ),
        ]..sort((left, right) {
          final date = left.date.compareTo(right.date);
          if (date != 0) return date;
          return left.title.compareTo(right.title);
        });

    final current = {
      for (final balance in balances)
        balance.account.id: balance.currentBalance,
    };
    final points = <DailyBalancePoint>[];
    var minimum = current.values.fold<int>(0, (sum, value) => sum + value);
    var minimumDate = start;
    for (var offset = 0; offset <= windowDays; offset++) {
      final date = DateTime(start.year, start.month, start.day + offset);
      final dayEvents = events.where((event) => event.date == date).toList();
      for (final event in dayEvents) {
        switch (event.type) {
          case TransactionType.income:
            current[event.accountId] =
                (current[event.accountId] ?? 0) + event.amount;
          case TransactionType.expense:
            current[event.accountId] =
                (current[event.accountId] ?? 0) - event.amount;
          case TransactionType.transfer:
            current[event.accountId] =
                (current[event.accountId] ?? 0) - event.amount;
            final target = event.transferAccountId!;
            current[target] = (current[target] ?? 0) + event.amount;
        }
      }
      final total = current.values.fold<int>(0, (sum, value) => sum + value);
      if (total < minimum) {
        minimum = total;
        minimumDate = date;
      }
      points.add(
        DailyBalancePoint(
          date: date,
          totalBalance: total,
          accountBalances: Map.unmodifiable(current),
          events: List.unmodifiable(dayEvents),
        ),
      );
    }

    final spendableIds = balances
        .where((item) => item.account.isSpendable)
        .map((item) => item.account.id)
        .toSet();
    final spendableBalance = balances
        .where((item) => item.account.isSpendable)
        .fold<int>(0, (sum, item) => sum + item.currentBalance);
    final nextIncome = events
        .where((event) => event.type == TransactionType.income)
        .map((event) => event.date)
        .firstOrNull;
    final reserveThrough = nextIncome ?? through;
    final reserved = events
        .where(
          (event) =>
              event.type == TransactionType.expense &&
              event.isEssential &&
              spendableIds.contains(event.accountId) &&
              !event.date.isAfter(reserveThrough),
        )
        .toList(growable: false);
    final reservedTotal = reserved.fold<int>(
      0,
      (sum, event) => sum + event.amount,
    );
    final safe = spendableBalance - reservedTotal - safetyBuffer;

    return CashFlowProjection(
      points: List.unmodifiable(points),
      events: List.unmodifiable(events),
      minimumBalance: minimum,
      minimumDate: minimumDate,
      safeToSpend: safe < 0 ? 0 : safe,
      spendableBalance: spendableBalance,
      safetyBuffer: safetyBuffer,
      reservedExpenses: List.unmodifiable(reserved),
      nextIncomeDate: nextIncome,
    );
  }
}
