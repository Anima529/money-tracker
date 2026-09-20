import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/features/accounts/data/account_dao.dart';
import 'package:money_tracker/features/accounts/data/drift_account_repository.dart';
import 'package:money_tracker/features/transactions/data/drift_transaction_repository.dart';
import 'package:money_tracker/features/transactions/data/transaction_dao.dart';
import 'package:money_tracker/features/transactions/domain/transaction.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('v1 migration preserves transactions and assigns stable defaults', () async {
    final directory = await Directory.systemTemp.createTemp(
      'money_tracker_migration_',
    );
    final file = File('${directory.path}/ledger.sqlite');
    final oldDatabase = sqlite.sqlite3.open(file.path);
    final createdAt = DateTime(2026, 8, 12, 10, 30);
    final updatedAt = DateTime(2026, 8, 13, 11, 45);
    final transactionDate = DateTime(2026, 8, 12);
    try {
      oldDatabase.execute('''
        CREATE TABLE transactions (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          amount INTEGER NOT NULL,
          category TEXT NOT NULL,
          note TEXT NOT NULL DEFAULT '',
          transaction_date INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          CHECK (type IN ('income', 'expense')),
          CHECK (amount BETWEEN 1 AND 999999999999)
        )
      ''');
      oldDatabase.execute(
        '''
          INSERT INTO transactions (
            id, type, amount, category, note, transaction_date, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          7,
          'expense',
          4321,
          'food',
          '旧账单',
          transactionDate.millisecondsSinceEpoch ~/ 1000,
          createdAt.millisecondsSinceEpoch ~/ 1000,
          updatedAt.millisecondsSinceEpoch ~/ 1000,
        ],
      );
      oldDatabase.execute(
        'CREATE INDEX transactions_date_idx ON transactions (transaction_date)',
      );
      oldDatabase.execute(
        'CREATE INDEX transactions_type_date_idx ON transactions (type, transaction_date)',
      );
      oldDatabase.execute('PRAGMA user_version = 1');
    } finally {
      oldDatabase.close();
    }

    final database = AppDatabase.forTesting(NativeDatabase(file));
    try {
      final accounts = await DriftAccountRepository(AccountDao(database))
          .getAll();
      final transactions = await DriftTransactionRepository(
        TransactionDao(database),
      ).getAll();
      expect(accounts, hasLength(1));
      expect(accounts.single.uuid, defaultAccountUuid);
      expect(transactions, hasLength(1));
      final transaction = transactions.single;
      expect(transaction.id, 7);
      expect(transaction.uuid, '00000000-0000-4000-8000-000000000007');
      expect(transaction.type, TransactionType.expense);
      expect(transaction.amount, 4321);
      expect(transaction.category, 'food');
      expect(transaction.note, '旧账单');
      expect(transaction.accountId, accounts.single.id);
      expect(transaction.status, TransactionStatus.confirmed);
      expect(transaction.source, TransactionSource.manual);
      expect(transaction.transactionDate, transactionDate);
      expect(transaction.createdAt, createdAt);
      expect(transaction.updatedAt, updatedAt);
      expect(transaction.confirmedAt, createdAt);
      expect(transaction.deletedAt, isNull);
      expect(
        (await database.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        4,
      );
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });

  test(
    'v2 migration adds skip and merchant rule tables without data loss',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'money_tracker_v2_migration_',
      );
      final file = File('${directory.path}/ledger.sqlite');
      final oldDatabase = sqlite.sqlite3.open(file.path);
      try {
        oldDatabase.execute('CREATE TABLE accounts (id INTEGER PRIMARY KEY)');
        oldDatabase.execute('CREATE TABLE schedules (id INTEGER PRIMARY KEY)');
        oldDatabase.execute(
          'CREATE TABLE transactions (id INTEGER PRIMARY KEY)',
        );
        oldDatabase.execute('CREATE TABLE sentinel (value TEXT NOT NULL)');
        oldDatabase.execute("INSERT INTO sentinel VALUES ('keep-me')");
        oldDatabase.execute('PRAGMA user_version = 2');
      } finally {
        oldDatabase.close();
      }

      final database = AppDatabase.forTesting(NativeDatabase(file));
      try {
        expect(
          (await database
                  .customSelect('SELECT value FROM sentinel')
                  .getSingle())
              .read<String>('value'),
          'keep-me',
        );
        final tables = await database
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
            .get();
        expect(
          tables.map((row) => row.read<String>('name')),
          containsAll(['schedule_skips', 'merchant_rules']),
        );
        final transactionColumns = await database
            .customSelect('PRAGMA table_info(transactions)')
            .get();
        expect(
          transactionColumns.map((row) => row.read<String>('name')),
          contains('deleted_at'),
        );
        expect(
          (await database.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          4,
        );
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
