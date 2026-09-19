import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/features/transactions/data/transaction_dao.dart';
import 'package:money_tracker/features/transactions/data/drift_transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction.dart';
import 'package:money_tracker/features/home/providers/home_providers.dart';

TransactionDraft draft({
  int amount = 1250,
  TransactionType type = TransactionType.expense,
  String? category,
  DateTime? date,
  String note = '',
  int accountId = 1,
  int? transferAccountId,
  TransactionStatus status = TransactionStatus.confirmed,
}) => TransactionDraft(
  type: type,
  amount: amount,
  category: category ?? (type == TransactionType.income ? 'salary' : 'food'),
  accountId: accountId,
  transferAccountId: transferAccountId,
  status: status,
  transactionDate: date ?? DateTime(2026, 9, 17, 12),
  note: note,
);

void main() {
  late AppDatabase database;
  var databaseClosed = false;
  late DriftTransactionRepository repository;
  late DateTime now;
  setUp(() {
    databaseClosed = false;
    now = DateTime(2026, 9, 17, 12);
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftTransactionRepository(
      TransactionDao(database),
      clock: () => now,
    );
  });
  tearDown(() async {
    if (!databaseClosed) await database.close();
  });

  test('CRUD preserves integer amount and creation timestamp', () async {
    final id = await repository.add(draft(note: ' 午餐 '));
    final original = (await repository.getAll()).single;
    expect(original.amount, 1250);
    expect(original.note, '午餐');
    expect(original.transactionDate, DateTime(2026, 9, 17));
    expect(original.createdAt, now);
    now = now.add(const Duration(hours: 1));
    expect(
      await repository.update(
        id,
        draft(amount: 9900, type: TransactionType.income),
      ),
      isTrue,
    );
    final updated = (await repository.getAll()).single;
    expect(updated.amount, 9900);
    expect(updated.type, TransactionType.income);
    expect(updated.category, 'salary');
    expect(updated.createdAt, original.createdAt);
    expect(updated.updatedAt, now);
    expect(await repository.delete(id), isTrue);
    expect(await repository.getAll(), isEmpty);
    expect(await repository.delete(id), isFalse);
    expect(await repository.update(id, draft()), isFalse);
  });

  test(
    'day/month/type queries use inclusive start and exclusive end',
    () async {
      await repository.add(draft(date: DateTime(2025, 12, 31, 23, 59)));
      final first = await repository.add(draft(date: DateTime(2026, 1, 1)));
      final income = await repository.add(
        draft(date: DateTime(2026, 1, 31), type: TransactionType.income),
      );
      await repository.add(draft(date: DateTime(2026, 2, 1)));
      expect(
        (await repository.getByMonth(DateTime(2026, 1, 15))).map((t) => t.id),
        [income, first],
      );
      expect(
        (await repository.getByDate(DateTime(2026, 1, 1, 18))).single.id,
        first,
      );
      expect(
        (await repository.getByMonth(
          DateTime(2026, 1),
          type: TransactionType.income,
        )).single.id,
        income,
      );
      expect(
        (await repository.getAll(type: TransactionType.expense)).length,
        3,
      );
      expect(await repository.getByDate(DateTime(2026, 1, 2)), isEmpty);
    },
  );

  test(
    'leap day is included once and same-day order is deterministic',
    () async {
      final first = await repository.add(draft(date: DateTime(2024, 2, 29)));
      final second = await repository.add(
        draft(date: DateTime(2024, 2, 29, 23, 59)),
      );
      await repository.add(draft(date: DateTime(2024, 3, 1)));
      expect(
        (await repository.getByMonth(DateTime(2024, 2))).map((t) => t.id),
        [second, first],
      );
    },
  );

  test('validation rejects invalid amounts, categories and notes', () async {
    for (final invalid in [
      draft(amount: 0),
      draft(amount: -1),
      draft(amount: 1000000000000),
      draft(category: 'unknown'),
      draft(type: TransactionType.income, category: 'food'),
      draft(note: 'x' * 1001),
    ]) {
      await expectLater(repository.add(invalid), throwsArgumentError);
    }
    expect(await repository.getAll(), isEmpty);
  });

  test('database also enforces amount and type constraints', () async {
    final value = TransactionsCompanion.insert(
      uuid: '10000000-0000-4000-8000-000000000001',
      type: 'expense',
      amount: 0,
      category: 'food',
      accountId: 1,
      status: 'confirmed',
      source: 'manual',
      transactionDate: now,
      confirmedAt: Value(now),
      createdAt: now,
      updatedAt: now,
    );
    await expectLater(
      database.into(database.transactions).insert(value),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      database
          .into(database.transactions)
          .insert(
            value.copyWith(
              amount: const Value(10),
              type: const Value('invalid'),
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('watchAll emits inserts, edits and deletions', () async {
    final stream = repository.watchAll();
    final expectation = expectLater(
      stream,
      emitsInOrder([
        isEmpty,
        predicate<List<Transaction>>(
          (rows) => rows.length == 1 && rows.single.amount == 1250,
        ),
        predicate<List<Transaction>>(
          (rows) => rows.length == 1 && rows.single.amount == 2500,
        ),
        isEmpty,
      ]),
    );
    // Await a subscription-visible snapshot after each mutation.
    await stream.first;
    final id = await repository.add(draft());
    await stream.firstWhere(
      (rows) => rows.length == 1 && rows.single.amount == 1250,
    );
    await repository.update(id, draft(amount: 2500));
    await stream.firstWhere(
      (rows) => rows.length == 1 && rows.single.amount == 2500,
    );
    await repository.delete(id);
    await expectation;
  });

  test('delete undo restores stable identity and audit fields', () async {
    final id = await repository.add(draft(note: '可撤销'));
    final original = (await repository.getAll()).single;
    expect(await repository.delete(id), isTrue);
    final restoredId = await repository.restore(original);
    final restored = (await repository.getAll()).single;
    expect(restoredId, isPositive);
    expect(restored.uuid, original.uuid);
    expect(restored.createdAt, original.createdAt);
    expect(restored.updatedAt, original.updatedAt);
    expect(restored.note, '可撤销');
  });

  test('recent limit and monthly summary are exact', () async {
    await repository.add(draft(amount: 10000, type: TransactionType.income));
    await repository.add(draft(amount: 1250));
    await repository.add(draft(amount: 2000, date: DateTime(2026, 8, 31)));
    final monthly = await repository.watchMonth(DateTime(2026, 9)).first;
    final summary = MonthlySummary.fromTransactions(monthly);
    expect(summary.income, 10000);
    expect(summary.expense, 1250);
    expect(summary.balance, 8750);
    expect((await repository.watchAll(limit: 1).first).single.amount, 1250);
    expect(() => repository.watchAll(limit: 0), throwsArgumentError);
  });

  test(
    'planned and suggested transactions do not enter monthly summary',
    () async {
      await repository.add(
        draft(
          amount: 5000,
          type: TransactionType.income,
          status: TransactionStatus.planned,
        ),
      );
      await repository.add(
        draft(amount: 1200, status: TransactionStatus.suggested),
      );
      await repository.add(draft(amount: 3000, type: TransactionType.income));
      final monthly = await repository.watchMonth(DateTime(2026, 9)).first;
      expect(monthly, hasLength(1));
      expect(MonthlySummary.fromTransactions(monthly).balance, 3000);
    },
  );

  test('transfer requires two different accounts', () async {
    for (final invalid in [
      draft(type: TransactionType.transfer, category: 'transfer'),
      draft(
        type: TransactionType.transfer,
        category: 'transfer',
        transferAccountId: 1,
      ),
      draft(transferAccountId: 2),
    ]) {
      await expectLater(repository.add(invalid), throwsArgumentError);
    }
  });

  test('SQLite file survives database recreation', () async {
    await database.close();
    databaseClosed = true;
    final directory = await Directory.systemTemp.createTemp(
      'money_tracker_test_',
    );
    final file = File('${directory.path}/ledger.sqlite');
    var persistent = AppDatabase.forTesting(NativeDatabase(file));
    try {
      final repo = DriftTransactionRepository(TransactionDao(persistent));
      await repo.add(draft(amount: 123456789));
      await persistent.close();
      persistent = AppDatabase.forTesting(NativeDatabase(file));
      final reopened = DriftTransactionRepository(TransactionDao(persistent));
      expect((await reopened.getAll()).single.amount, 123456789);
    } finally {
      await persistent.close();
      await directory.delete(recursive: true);
    }
  });
}
