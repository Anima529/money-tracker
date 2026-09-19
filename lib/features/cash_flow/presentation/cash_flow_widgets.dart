import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_dates.dart';
import '../../../core/utils/money.dart';
import '../../accounts/providers/account_providers.dart';
import '../../schedules/presentation/schedule_editor_sheet.dart';
import '../../schedules/presentation/schedule_manager_sheet.dart';
import '../../schedules/providers/schedule_providers.dart';
import '../../schedules/domain/schedule.dart';
import '../../schedules/domain/schedule_instance.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/transaction_editor_sheet.dart';
import '../../transactions/providers/transaction_providers.dart';
import '../domain/cash_flow_projection.dart';
import '../providers/cash_flow_providers.dart';

class HomeCashFlowCard extends ConsumerWidget {
  const HomeCashFlowCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(cashFlowProjectionProvider)
      .when(
        loading: () => const Card(
          child: SizedBox(
            height: 112,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
        error: (error, stack) => const SizedBox.shrink(),
        data: (projection) => Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => CashFlowHeader._showExplanation(context, projection),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('安心可花'),
                        const SizedBox(height: 4),
                        Text(
                          Money.format(projection.safeToSpend),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '未来最低 ${Money.format(projection.minimumBalance)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
      );
}

class CashFlowHeader extends ConsumerWidget {
  const CashFlowHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(cashFlowProjectionProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        children: [
          Card(
            child: value.when(
              loading: () => const SizedBox(
                height: 112,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => const ListTile(
                leading: Icon(Icons.error_outline),
                title: Text('未来现金流暂时无法计算'),
              ),
              data: (projection) => InkWell(
                onTap: () => _showExplanation(context, projection),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('安心可花'),
                            const SizedBox(height: 4),
                            Text(
                              Money.format(projection.safeToSpend),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '未来最低 ${Money.format(projection.minimumBalance)} · ${AppDates.dayLabel(projection.minimumDate)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showTransactionEditor(
                    context,
                    title: '一次性计划',
                    initialStatus: TransactionStatus.planned,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                  ),
                  icon: const Icon(Icons.event_outlined),
                  label: const Text('计划一笔'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showScheduleManager(context),
                  icon: const Icon(Icons.event_repeat_rounded),
                  label: const Text('周期计划'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> _showExplanation(
    BuildContext context,
    CashFlowProjection projection,
  ) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Text('安心可花如何计算', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _ExplainRow(label: '可支配账户余额', amount: projection.spendableBalance),
        for (final event in projection.reservedExpenses)
          _ExplainRow(label: '预留 · ${event.title}', amount: -event.amount),
        _ExplainRow(label: '安全垫', amount: -projection.safetyBuffer),
        const Divider(height: 28),
        _ExplainRow(
          label: '安心可花',
          amount: projection.safeToSpend,
          strong: true,
        ),
        const SizedBox(height: 12),
        Text(
          projection.nextIncomeDate == null
              ? '未来 30 天没有计划收入，按完整窗口预留。'
              : '预留范围截止到 ${AppDates.dayLabel(projection.nextIncomeDate!)} 的下一笔计划收入。',
        ),
        const SizedBox(height: 24),
        Text('未来最低余额', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          '${AppDates.dayLabel(projection.minimumDate)} · ${Money.format(projection.minimumBalance)}',
        ),
        const SizedBox(height: 8),
        if (projection.events
            .where((event) => !event.date.isAfter(projection.minimumDate))
            .isEmpty)
          const Text('窗口内没有计划事件，最低余额来自当前账户余额。')
        else
          for (final event in projection.events.where(
            (event) => !event.date.isAfter(projection.minimumDate),
          ))
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(event.title),
              subtitle: Text(AppDates.dayLabel(event.date)),
              trailing: Text(
                '${event.type == TransactionType.expense
                    ? '−'
                    : event.type == TransactionType.income
                    ? '+'
                    : ''}${Money.format(event.amount)}',
              ),
            ),
      ],
    ),
  );
}

class FutureCashFlowList extends ConsumerWidget {
  const FutureCashFlowList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountNames = {
      for (final account
          in ref.watch(accountsProvider).asData?.value ?? const [])
        account.id: account.name,
    };
    return ref
        .watch(cashFlowProjectionProvider)
        .when(
          loading: () => const SizedBox.shrink(),
          error: (error, stack) => const SizedBox.shrink(),
          data: (projection) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (projection.events.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: Text(
                    '未来 30 天',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              for (final event in projection.events)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.schedule_rounded),
                      title: Text(event.title),
                      subtitle: Text(
                        '${AppDates.dayLabel(event.date)} · ${accountNames[event.accountId] ?? '账户 #${event.accountId}'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(Money.format(event.amount)),
                          PopupMenuButton<String>(
                            onSelected: (action) =>
                                _handleAction(context, ref, event, action),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'confirm',
                                child: Text('确认发生'),
                              ),
                              if (event.scheduleInstance != null) ...const [
                                PopupMenuItem(
                                  value: 'skip',
                                  child: Text('跳过本次'),
                                ),
                                PopupMenuItem(
                                  value: 'once',
                                  child: Text('只修改本次'),
                                ),
                                PopupMenuItem(
                                  value: 'future',
                                  child: Text('修改后续计划'),
                                ),
                              ] else ...const [
                                PopupMenuItem(value: 'edit', child: Text('编辑')),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('删除'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
  }

  static Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    CashFlowEvent event,
    String action,
  ) async {
    try {
      final instance = event.scheduleInstance;
      final transaction = event.transaction;
      if (action == 'confirm') {
        if (instance != null) {
          await ref
              .read(transactionRepositoryProvider)
              .add(instance.toTransactionDraft());
          await _advanceIfNext(ref, instance);
        } else if (transaction != null) {
          await ref
              .read(transactionRepositoryProvider)
              .update(
                transaction.id,
                _transactionDraft(
                  transaction,
                  status: TransactionStatus.confirmed,
                ),
              );
        }
      } else if (action == 'skip' && instance != null) {
        await ref
            .read(scheduleRepositoryProvider)
            .skip(instance.schedule.id, instance.scheduledFor);
        await _advanceIfNext(ref, instance);
      } else if (action == 'once' && instance != null) {
        final saved = await showTransactionEditor(
          context,
          title: '只修改本次',
          initialDraft: instance.toTransactionDraft(
            status: TransactionStatus.planned,
          ),
        );
        if (saved == true) await _advanceIfNext(ref, instance);
      } else if (action == 'future' && instance != null) {
        await showScheduleEditor(
          context,
          initial: instance.schedule,
          effectiveFrom: instance.scheduledFor,
        );
      } else if (action == 'edit' && transaction != null) {
        await showTransactionEditor(context, initial: transaction);
      } else if (action == 'delete' && transaction != null) {
        await ref.read(transactionRepositoryProvider).delete(transaction.id);
      }
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
      }
    }
  }

  static Future<void> _advanceIfNext(
    WidgetRef ref,
    ScheduleInstance instance,
  ) async {
    final schedule = instance.schedule;
    if (AppDates.dayStart(schedule.nextDate) !=
        AppDates.dayStart(instance.scheduledFor)) {
      return;
    }
    await ref
        .read(scheduleRepositoryProvider)
        .update(
          schedule.id,
          ScheduleDraft(
            title: schedule.title,
            type: schedule.type,
            amount: schedule.amount,
            category: schedule.category,
            accountId: schedule.accountId,
            transferAccountId: schedule.transferAccountId,
            frequency: schedule.frequency,
            interval: schedule.interval,
            startDate: schedule.startDate,
            nextDate: ScheduleRecurrence.next(schedule, instance.scheduledFor),
            endDate: schedule.endDate,
            isEssential: schedule.isEssential,
            isEnabled: schedule.isEnabled,
          ),
        );
  }

  static TransactionDraft _transactionDraft(
    Transaction transaction, {
    required TransactionStatus status,
  }) => TransactionDraft(
    type: transaction.type,
    amount: transaction.amount,
    category: transaction.category,
    accountId: transaction.accountId,
    transferAccountId: transaction.transferAccountId,
    status: status,
    source: transaction.source,
    merchant: transaction.merchant,
    confidence: transaction.confidence,
    scheduleId: transaction.scheduleId,
    scheduledFor: transaction.scheduledFor,
    sourceFingerprint: transaction.sourceFingerprint,
    note: transaction.note,
    transactionDate: transaction.transactionDate,
  );
}

class _ExplainRow extends StatelessWidget {
  const _ExplainRow({
    required this.label,
    required this.amount,
    this.strong = false,
  });

  final String label;
  final int amount;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: strong ? const TextStyle(fontWeight: FontWeight.w700) : null,
          ),
        ),
        Text(
          Money.format(amount),
          style: strong ? const TextStyle(fontWeight: FontWeight.w700) : null,
        ),
      ],
    ),
  );
}
