import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_dates.dart';
import '../../accounts/providers/account_providers.dart';
import '../../schedules/domain/schedule_instance.dart';
import '../../schedules/providers/schedule_providers.dart';
import '../../settings/providers/safety_buffer_provider.dart';
import '../../transactions/providers/transaction_providers.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/cash_flow_projection.dart';

final cashFlowProjectionProvider = Provider<AsyncValue<CashFlowProjection>>((
  ref,
) {
  final balances = ref.watch(accountBalancesProvider);
  final schedules = ref.watch(schedulesProvider);
  final skips = ref.watch(scheduleSkipsProvider);
  final transactions = ref.watch(allTransactionsProvider);
  if (balances.isLoading ||
      schedules.isLoading ||
      skips.isLoading ||
      transactions.isLoading) {
    return const AsyncLoading();
  }
  final error =
      balances.asError ??
      schedules.asError ??
      skips.asError ??
      transactions.asError;
  if (error != null) return AsyncError(error.error, error.stackTrace);

  final today = AppDates.dayStart(DateTime.now());
  final through = DateTime(today.year, today.month, today.day + 30);
  final allTransactions = transactions.requireValue;
  final handled = <int, Set<DateTime>>{};
  for (final transaction in allTransactions) {
    if (transaction.scheduleId != null && transaction.scheduledFor != null) {
      handled
          .putIfAbsent(transaction.scheduleId!, () => <DateTime>{})
          .add(AppDates.dayStart(transaction.scheduledFor!));
    }
  }
  for (final skip in skips.requireValue) {
    handled
        .putIfAbsent(skip.scheduleId, () => <DateTime>{})
        .add(AppDates.dayStart(skip.scheduledFor));
  }
  final instances = <ScheduleInstance>[
    for (final schedule in schedules.requireValue)
      ...ScheduleRecurrence.expand(
        schedule,
        from: today,
        through: through,
        handledDates: handled[schedule.id] ?? const {},
      ),
  ];
  return AsyncData(
    CashFlowProjection.calculate(
      today: today,
      balances: balances.requireValue,
      scheduleInstances: instances,
      plannedTransactions: allTransactions
          .where((item) => item.status == TransactionStatus.planned)
          .toList(growable: false),
      safetyBuffer: ref.watch(safetyBufferProvider),
    ),
  );
});
