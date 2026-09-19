import '../../../core/utils/app_dates.dart';
import '../../transactions/domain/transaction.dart';
import 'schedule.dart';

class ScheduleInstance {
  const ScheduleInstance({required this.schedule, required this.scheduledFor});

  final Schedule schedule;
  final DateTime scheduledFor;

  TransactionDraft toTransactionDraft({
    TransactionStatus status = TransactionStatus.confirmed,
  }) => TransactionDraft(
    type: schedule.type,
    amount: schedule.amount,
    category: schedule.category,
    accountId: schedule.accountId,
    transferAccountId: schedule.transferAccountId,
    status: status,
    source: TransactionSource.schedule,
    scheduleId: schedule.id,
    scheduledFor: scheduledFor,
    transactionDate: scheduledFor,
    note: schedule.title,
  );
}

class ScheduleSkip {
  const ScheduleSkip({
    required this.id,
    required this.scheduleId,
    required this.scheduledFor,
    required this.createdAt,
  });

  final int id;
  final int scheduleId;
  final DateTime scheduledFor;
  final DateTime createdAt;
}

/// 按原始起始日锚定周期；短月取月末，后续月份仍回到原始日。
abstract final class ScheduleRecurrence {
  static List<ScheduleInstance> expand(
    Schedule schedule, {
    required DateTime from,
    required DateTime through,
    Set<DateTime> handledDates = const {},
  }) {
    if (!schedule.isEnabled) return const [];
    final start = AppDates.dayStart(from);
    final end = AppDates.dayStart(through);
    final scheduleEnd = schedule.endDate == null
        ? end
        : AppDates.dayStart(schedule.endDate!).isBefore(end)
        ? AppDates.dayStart(schedule.endDate!)
        : end;
    var date = AppDates.dayStart(schedule.nextDate);
    final result = <ScheduleInstance>[];
    var guard = 0;
    while (!date.isAfter(scheduleEnd) && guard++ < 50000) {
      if (!date.isBefore(start) && !handledDates.contains(date)) {
        result.add(ScheduleInstance(schedule: schedule, scheduledFor: date));
      }
      date = next(schedule, date);
    }
    return result;
  }

  static DateTime next(Schedule schedule, DateTime occurrence) {
    final date = AppDates.dayStart(occurrence);
    return switch (schedule.frequency) {
      ScheduleFrequency.weekly => DateTime(
        date.year,
        date.month,
        date.day + 7 * schedule.interval,
      ),
      ScheduleFrequency.custom => DateTime(
        date.year,
        date.month,
        date.day + schedule.interval,
      ),
      ScheduleFrequency.monthly => _monthly(schedule, date),
      ScheduleFrequency.yearly => _yearly(schedule, date),
    };
  }

  static DateTime _monthly(Schedule schedule, DateTime occurrence) {
    final anchor = AppDates.dayStart(schedule.startDate);
    final currentIndex =
        (occurrence.year - anchor.year) * 12 + occurrence.month - anchor.month;
    final targetIndex = currentIndex + schedule.interval;
    final first = DateTime(anchor.year, anchor.month + targetIndex);
    return _clampedDate(first.year, first.month, anchor.day);
  }

  static DateTime _yearly(Schedule schedule, DateTime occurrence) {
    final anchor = AppDates.dayStart(schedule.startDate);
    return _clampedDate(
      occurrence.year + schedule.interval,
      anchor.month,
      anchor.day,
    );
  }

  static DateTime _clampedDate(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > lastDay ? lastDay : day);
  }
}
