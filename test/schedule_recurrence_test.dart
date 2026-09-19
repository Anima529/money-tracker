import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/features/schedules/domain/schedule.dart';
import 'package:money_tracker/features/schedules/domain/schedule_instance.dart';
import 'package:money_tracker/features/transactions/domain/transaction.dart';

Schedule schedule({
  required DateTime start,
  required ScheduleFrequency frequency,
  int interval = 1,
  DateTime? next,
  DateTime? end,
  bool enabled = true,
}) => Schedule(
  id: 1,
  uuid: '10000000-0000-4000-8000-000000000001',
  title: '计划',
  type: TransactionType.expense,
  amount: 100,
  category: 'housing',
  accountId: 1,
  transferAccountId: null,
  frequency: frequency,
  interval: interval,
  startDate: start,
  nextDate: next ?? start,
  endDate: end,
  isEssential: true,
  isEnabled: enabled,
  createdAt: start,
  updatedAt: start,
);

void main() {
  test('monthly recurrence clamps short months and returns to anchor day', () {
    final dates = ScheduleRecurrence.expand(
      schedule(
        start: DateTime(2027, 1, 31),
        frequency: ScheduleFrequency.monthly,
      ),
      from: DateTime(2027, 1, 1),
      through: DateTime(2027, 4, 30),
    ).map((item) => item.scheduledFor).toList();
    expect(dates, [
      DateTime(2027, 1, 31),
      DateTime(2027, 2, 28),
      DateTime(2027, 3, 31),
      DateTime(2027, 4, 30),
    ]);
  });

  test('yearly leap-day recurrence returns to leap day', () {
    final dates = ScheduleRecurrence.expand(
      schedule(
        start: DateTime(2024, 2, 29),
        frequency: ScheduleFrequency.yearly,
      ),
      from: DateTime(2024, 1, 1),
      through: DateTime(2028, 12, 31),
    ).map((item) => item.scheduledFor).toList();
    expect(dates, [
      DateTime(2024, 2, 29),
      DateTime(2025, 2, 28),
      DateTime(2026, 2, 28),
      DateTime(2027, 2, 28),
      DateTime(2028, 2, 29),
    ]);
  });

  test('handled, ended and disabled occurrences stay out of expansion', () {
    final base = schedule(
      start: DateTime(2026, 9, 1),
      frequency: ScheduleFrequency.weekly,
      end: DateTime(2026, 9, 20),
    );
    final dates = ScheduleRecurrence.expand(
      base,
      from: DateTime(2026, 9, 1),
      through: DateTime(2026, 9, 30),
      handledDates: {DateTime(2026, 9, 8)},
    ).map((item) => item.scheduledFor).toList();
    expect(dates, [DateTime(2026, 9, 1), DateTime(2026, 9, 15)]);
    expect(
      ScheduleRecurrence.expand(
        schedule(
          start: DateTime(2026, 9, 1),
          frequency: ScheduleFrequency.custom,
          enabled: false,
        ),
        from: DateTime(2026, 9, 1),
        through: DateTime(2026, 9, 30),
      ),
      isEmpty,
    );
  });
}
