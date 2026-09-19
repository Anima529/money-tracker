import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/features/schedules/data/drift_schedule_repository.dart';
import 'package:money_tracker/features/schedules/data/schedule_dao.dart';
import 'package:money_tracker/features/schedules/data/schedule_skip_dao.dart';
import 'package:money_tracker/features/schedules/domain/schedule.dart';
import 'package:money_tracker/features/transactions/domain/transaction.dart';

void main() {
  late AppDatabase database;
  late DriftScheduleRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftScheduleRepository(
      ScheduleDao(database),
      ScheduleSkipDao(database),
    );
  });

  tearDown(() => database.close());

  test('schedule CRUD preserves recurrence data', () async {
    final id = await repository.add(
      ScheduleDraft(
        title: ' 房租 ',
        type: TransactionType.expense,
        amount: 250000,
        category: 'housing',
        accountId: 1,
        frequency: ScheduleFrequency.monthly,
        startDate: DateTime(2026, 9, 20, 12),
        nextDate: DateTime(2026, 10, 20, 12),
        isEssential: true,
      ),
    );
    final schedule = (await repository.getAll()).single;
    expect(schedule.id, id);
    expect(schedule.title, '房租');
    expect(schedule.startDate, DateTime(2026, 9, 20));
    expect(schedule.nextDate, DateTime(2026, 10, 20));
    expect(schedule.isEssential, isTrue);

    expect(
      await repository.update(
        id,
        ScheduleDraft(
          title: '房租',
          type: TransactionType.expense,
          amount: 260000,
          category: 'housing',
          accountId: 1,
          frequency: ScheduleFrequency.monthly,
          startDate: DateTime(2026, 9, 20),
          nextDate: DateTime(2026, 11, 20),
          isEnabled: false,
        ),
      ),
      isTrue,
    );
    expect(await repository.getAll(enabledOnly: true), isEmpty);
    expect(await repository.delete(id), isTrue);
  });

  test(
    'schedule validation rejects invalid transfers and date ranges',
    () async {
      final base = DateTime(2026, 9, 20);
      expect(
        () => repository.add(
          ScheduleDraft(
            title: '转账',
            type: TransactionType.transfer,
            amount: 100,
            category: 'transfer',
            accountId: 1,
            transferAccountId: 1,
            frequency: ScheduleFrequency.monthly,
            startDate: base,
            nextDate: base,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => repository.add(
          ScheduleDraft(
            title: '工资',
            type: TransactionType.income,
            amount: 100,
            category: 'salary',
            accountId: 1,
            frequency: ScheduleFrequency.monthly,
            startDate: base,
            nextDate: base.subtract(const Duration(days: 1)),
          ),
        ),
        throwsArgumentError,
      );
    },
  );

  test('skipped occurrence is persisted once and can be restored', () async {
    final date = DateTime(2026, 10, 1);
    final id = await repository.add(
      ScheduleDraft(
        title: '房租',
        type: TransactionType.expense,
        amount: 250000,
        category: 'housing',
        accountId: 1,
        frequency: ScheduleFrequency.monthly,
        startDate: date,
        nextDate: date,
      ),
    );
    await repository.skip(id, date);
    final skip = (await repository.getSkips()).single;
    expect(skip.scheduleId, id);
    expect(skip.scheduledFor, date);
    await expectLater(repository.skip(id, date), throwsA(isA<Exception>()));
    expect(await repository.unskip(id, date), isTrue);
    expect(await repository.getSkips(), isEmpty);
  });
}
