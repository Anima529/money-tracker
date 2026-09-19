import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../providers/home_providers.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.summary});

  /// 要展示的本月收支汇总。
  final MonthlySummary summary;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本月结余',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Money.format(summary.balance),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _Amount(
                    label: '本月收入',
                    amount: summary.income,
                    income: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _Amount(
                    label: '本月支出',
                    amount: summary.expense,
                    income: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({
    required this.label,
    required this.amount,
    required this.income,
  });

  /// 金额上方的说明文字。
  final String label;

  /// 展示金额，单位为分。
  final int amount;

  /// 是否使用收入配色。
  final bool income;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 8),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          Money.format(amount),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.transaction(context, income: income),
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ],
  );
}
