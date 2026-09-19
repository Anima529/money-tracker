import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/features/accounts/data/account_dao.dart';
import 'package:money_tracker/features/accounts/data/drift_account_repository.dart';
import 'package:money_tracker/features/accounts/domain/account.dart';
import 'package:money_tracker/features/transactions/data/drift_transaction_repository.dart';
import 'package:money_tracker/features/transactions/data/transaction_dao.dart';
import 'package:money_tracker/features/transactions/domain/transaction.dart';
import 'package:money_tracker/features/home/providers/home_providers.dart';

void main() {
  late AppDatabase database;
  late DriftAccountRepository accounts;
  late DriftTransactionRepository transactions;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    accounts = DriftAccountRepository(AccountDao(database));
    transactions = DriftTransactionRepository(TransactionDao(database));
  });

  tearDown(() => database.close());

  test('new database contains a usable default account', () async {
    final account = (await accounts.getAll()).single;
    expect(account.uuid, defaultAccountUuid);
    expect(account.name, '默认账户');
    expect(account.initialBalance, 0);
  });

  test(
    'balances include confirmed flows and transfers cancel in total',
    () async {
      final defaultAccount = (await accounts.getAll()).single;
      await accounts.update(
        defaultAccount.id,
        const AccountDraft(
          name: '现金',
          type: AccountType.cash,
          initialBalance: 10000,
        ),
      );
      final bankId = await accounts.add(
        const AccountDraft(
          name: '银行卡',
          type: AccountType.bank,
          initialBalance: 5000,
          sortOrder: 1,
        ),
      );
      final day = DateTime(2026, 9, 19);
      await transactions.add(
        TransactionDraft(
          type: TransactionType.income,
          amount: 3000,
          category: 'salary',
          accountId: defaultAccount.id,
          transactionDate: day,
        ),
      );
      await transactions.add(
        TransactionDraft(
          type: TransactionType.expense,
          amount: 1000,
          category: 'food',
          accountId: defaultAccount.id,
          transactionDate: day,
        ),
      );
      await transactions.add(
        TransactionDraft(
          type: TransactionType.transfer,
          amount: 2500,
          category: 'transfer',
          accountId: defaultAccount.id,
          transferAccountId: bankId,
          transactionDate: day,
        ),
      );
      await transactions.add(
        TransactionDraft(
          type: TransactionType.expense,
          amount: 9000,
          category: 'housing',
          accountId: defaultAccount.id,
          transactionDate: day,
          status: TransactionStatus.planned,
        ),
      );
      await transactions.add(
        TransactionDraft(
          type: TransactionType.income,
          amount: 99000,
          category: 'salary',
          accountId: bankId,
          transactionDate: day,
          status: TransactionStatus.suggested,
          source: TransactionSource.notification,
        ),
      );

      final balances = await accounts.getBalances();
      expect(balances.map((item) => item.currentBalance), [9500, 7500]);
      expect(
        balances.fold<int>(0, (sum, item) => sum + item.currentBalance),
        17000,
      );

      final summary = MonthlySummary.fromTransactions(
        await transactions.watchMonth(day).first,
      );
      expect(summary.income, 3000);
      expect(summary.expense, 1000);
      expect(summary.balance, 2000);
    },
  );

  test('database rejects transfers to the same account', () async {
    final accountId = (await accounts.getAll()).single.id;
    await expectLater(
      database
          .into(database.transactions)
          .insert(
            TransactionsCompanion.insert(
              uuid: '20000000-0000-4000-8000-000000000001',
              type: 'transfer',
              amount: 100,
              category: 'transfer',
              accountId: accountId,
              transferAccountId: Value(accountId),
              status: 'confirmed',
              source: 'manual',
              transactionDate: DateTime(2026, 9, 19),
              confirmedAt: Value(DateTime(2026, 9, 19)),
              createdAt: DateTime(2026, 9, 19),
              updatedAt: DateTime(2026, 9, 19),
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });
}
