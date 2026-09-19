import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/app_dates.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/async_content.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../cash_flow/providers/cash_flow_providers.dart';
import '../../transactions/presentation/transaction_tile.dart';
import '../../transactions/presentation/transaction_detail_sheet.dart';
import '../../transactions/presentation/transaction_editor_sheet.dart';
import '../../cash_flow/presentation/cash_flow_widgets.dart';
import '../../transactions/providers/transaction_providers.dart';
import '../providers/home_providers.dart';
import 'summary_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month =
        ref.watch(currentMonthProvider).asData?.value ??
        AppDates.monthStart(DateTime.now());
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 112),
      children: [
        Text(
          AppDates.monthLabel(month),
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '让每一笔，都心中有数',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        const HomeCashFlowCard(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () =>
                    showTransactionEditor(context, showQuickInput: true),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('一句话记账'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showTransactionEditor(context),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('手动记账'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AsyncContent(
          value: ref.watch(monthlySummaryProvider(month)),
          builder: (summary) => SummaryCard(summary: summary),
          onRetry: () => ref.invalidate(monthlyTransactionsProvider(month)),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('接下来', style: theme.textTheme.titleLarge),
            TextButton(
              onPressed: () => context.go('/statistics'),
              child: const Text('查看未来'),
            ),
          ],
        ),
        ref
            .watch(cashFlowProjectionProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => const SizedBox.shrink(),
              data: (projection) => projection.events.isEmpty
                  ? Card(
                      child: ListTile(
                        leading: const Icon(Icons.event_available_outlined),
                        title: const Text('未来 30 天暂无计划'),
                        subtitle: const Text('添加周期事项后，会在这里提前提醒。'),
                        onTap: () => context.go('/statistics'),
                      ),
                    )
                  : Column(
                      children: [
                        for (final event in projection.events.take(3))
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.schedule_rounded),
                              title: Text(event.title),
                              subtitle: Text(AppDates.dayLabel(event.date)),
                              trailing: Text(
                                Money.format(event.amount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('最近账单', style: theme.textTheme.titleLarge),
            TextButton(
              onPressed: () => context.go('/transactions'),
              child: const Text('查看全部'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: AsyncContent(
            value: ref.watch(recentTransactionsProvider),
            onRetry: () => ref.invalidate(recentTransactionsProvider),
            builder: (transactions) => transactions.isEmpty
                ? const EmptyState(
                    title: '生活的账，从这里开始',
                    message: '还没有账单，收入与支出会在这里清晰呈现。',
                  )
                : Column(
                    children: [
                      for (final transaction in transactions)
                        TransactionTile(
                          transaction: transaction,
                          onTap: () =>
                              showTransactionDetail(context, transaction),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
