import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/app_dates.dart';
import '../../../core/utils/money.dart';
import '../domain/transaction.dart';
import '../domain/transaction_category.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.subtitlePrefix,
  });

  /// 当前列表项展示的交易。
  final Transaction transaction;
  final VoidCallback? onTap;

  /// 日期分组列表可改为显示账户名，避免重复日期。
  final String? subtitlePrefix;
  @override
  Widget build(BuildContext context) {
    final category = Categories.find(transaction.category);
    final income = transaction.type == TransactionType.income;
    final transfer = transaction.type == TransactionType.transfer;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(category?.colorValue ?? 0xFF7B8187)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _icon(category?.iconKey),
                size: 22,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transfer ? '转账' : (category?.name ?? '未分类'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${subtitlePrefix ?? AppDates.dayLabel(transaction.transactionDate)}${transaction.merchant == null ? '' : ' · ${transaction.merchant}'}${transaction.note.isEmpty ? '' : ' · ${transaction.note}'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${transfer ? '' : (income ? '+' : '−')}${Money.format(transaction.amount)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.transaction(context, income: income),
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _icon(String? key) => switch (key) {
    'restaurant' => Icons.restaurant_outlined,
    'train' => Icons.directions_transit_outlined,
    'shopping' => Icons.shopping_bag_outlined,
    'movie' => Icons.movie_outlined,
    'home' => Icons.home_outlined,
    'health' => Icons.favorite_outline,
    'school' => Icons.school_outlined,
    'work' => Icons.work_outline,
    'award' => Icons.emoji_events_outlined,
    'trend' => Icons.trending_up,
    'gift' => Icons.redeem_outlined,
    _ => Icons.more_horiz,
  };
}
