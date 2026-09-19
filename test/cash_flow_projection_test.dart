import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/features/accounts/domain/account.dart';
import 'package:money_tracker/features/cash_flow/domain/cash_flow_projection.dart';
import 'package:money_tracker/features/schedules/domain/schedule.dart';
import 'package:money_tracker/features/schedules/domain/schedule_instance.dart';
import 'package:money_tracker/features/transactions/domain/transaction.dart';

AccountBalance balance(int id, int cents, {bool spendable = true}) =>
    AccountBalance(
      account: Account(
        id: id,
        uuid: '10000000-0000-4000-8000-${id.toString().padLeft(12, '0')}',
        name: '账户$id',
        type: AccountType.other,
        initialBalance: cents,
        icon: 'wallet',
        color: 0xff000000,
        isSpendable: spendable,
        isArchived: false,
        sortOrder: id,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      currentBalance: cents,
    );

ScheduleInstance instance({
  required int id,
  required DateTime date,
  required TransactionType type,
  required int amount,
  int accountId = 1,
  int? transferAccountId,
  bool essential = false,
}) => ScheduleInstance(
  schedule: Schedule(
    id: id,
    uuid: '20000000-0000-4000-8000-${id.toString().padLeft(12, '0')}',
    title: '事件$id',
    type: type,
    amount: amount,
    category: type == TransactionType.income
        ? 'salary'
        : type == TransactionType.transfer
        ? 'transfer'
        : 'housing',
    accountId: accountId,
    transferAccountId: transferAccountId,
    frequency: ScheduleFrequency.monthly,
    interval: 1,
    startDate: date,
    nextDate: date,
    endDate: null,
    isEssential: essential,
    isEnabled: true,
    createdAt: date,
    updatedAt: date,
  ),
  scheduledFor: date,
);

void main() {
  test('projection preserves transfers and finds minimum balance', () {
    final today = DateTime(2026, 9, 1);
    final projection = CashFlowProjection.calculate(
      today: today,
      balances: [balance(1, 100000), balance(2, 50000)],
      scheduleInstances: [
        instance(
          id: 1,
          date: DateTime(2026, 9, 2),
          type: TransactionType.transfer,
          amount: 20000,
          transferAccountId: 2,
        ),
        instance(
          id: 2,
          date: DateTime(2026, 9, 3),
          type: TransactionType.expense,
          amount: 30000,
          essential: true,
        ),
        instance(
          id: 3,
          date: DateTime(2026, 9, 5),
          type: TransactionType.income,
          amount: 50000,
        ),
      ],
      plannedTransactions: const [],
      safetyBuffer: 10000,
    );
    expect(projection.points[1].totalBalance, 150000);
    expect(projection.points[1].accountBalances, {1: 80000, 2: 70000});
    expect(projection.minimumBalance, 120000);
    expect(projection.minimumDate, DateTime(2026, 9, 3));
    expect(projection.safeToSpend, 110000);
    expect(projection.nextIncomeDate, DateTime(2026, 9, 5));
  });

  test('safe-to-spend ignores non-spendable account balances', () {
    final projection = CashFlowProjection.calculate(
      today: DateTime(2026, 9, 1),
      balances: [balance(1, 50000), balance(2, 900000, spendable: false)],
      scheduleInstances: const [],
      plannedTransactions: const [],
      safetyBuffer: 60000,
    );
    expect(projection.safeToSpend, 0);
  });
}
