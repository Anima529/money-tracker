import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_dates.dart';
import '../../../core/utils/money.dart';
import '../../cash_flow/domain/cash_flow_projection.dart';
import '../../cash_flow/presentation/cash_flow_widgets.dart';
import '../../cash_flow/providers/cash_flow_providers.dart';
import '../../schedules/presentation/schedule_manager_sheet.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/transaction_editor_sheet.dart';

/// 阶段 4 的未来现金流主页面；传统消费洞察留待阶段 7。
class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projection = ref.watch(cashFlowProjectionProvider);
    return ListView(
      padding: const EdgeInsets.only(bottom: 112),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '接下来 30 天',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '计划改变后，预测会立即更新。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const CashFlowHeader(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: projection.when(
            loading: () => const Card(
              child: SizedBox(
                height: 230,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (error, stack) => const Card(
              child: ListTile(
                leading: Icon(Icons.error_outline),
                title: Text('余额曲线暂时无法加载'),
              ),
            ),
            data: (value) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BalanceChart(projection: value),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('近期事项', style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => showScheduleManager(context),
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('管理计划'),
                    ),
                  ],
                ),
                if (value.events.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('未来 30 天还没有计划事项。'),
                    ),
                  )
                else
                  for (final event in value.events.take(6))
                    Card(
                      child: ListTile(
                        leading: Icon(_eventIcon(event.type)),
                        title: Text(event.title),
                        subtitle: Text(AppDates.dayLabel(event.date)),
                        trailing: Text(
                          '${event.type == TransactionType.expense
                              ? '−'
                              : event.type == TransactionType.income
                              ? '+'
                              : ''}${Money.format(event.amount)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => showTransactionEditor(
                    context,
                    title: '一次性计划',
                    initialStatus: TransactionStatus.planned,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('添加一次性计划'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static IconData _eventIcon(TransactionType type) => switch (type) {
    TransactionType.income => Icons.south_west_rounded,
    TransactionType.expense => Icons.north_east_rounded,
    TransactionType.transfer => Icons.swap_horiz_rounded,
  };
}

class _BalanceChart extends StatelessWidget {
  const _BalanceChart({required this.projection});

  final CashFlowProjection projection;

  @override
  Widget build(BuildContext context) {
    // fl_chart 只接收 double；货币计算已经在进入绘图层前用整数分完成。
    final spots = [
      for (var index = 0; index < projection.points.length; index++)
        FlSpot(index.toDouble(), projection.points[index].totalBalance / 100),
    ];
    final values = projection.points.map((point) => point.totalBalance);
    final minCents = values.reduce(
      (left, right) => left < right ? left : right,
    );
    final maxCents = values.reduce(
      (left, right) => left > right ? left : right,
    );
    final range = (maxCents - minCents).abs();
    final padding = range == 0 ? 10000 : (range * 0.15).round();
    final minY = (minCents - padding) / 100;
    final maxY = (maxCents + padding) / 100;
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('预计余额', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 18),
            SizedBox(
              height: 210,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 30,
                  minY: minY,
                  maxY: maxY,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        getTitlesWidget: (value, meta) => Text(
                          _compactYuan(value),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 10,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            value == 0 ? '今天' : '+${value.round()}天',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => [
                        for (final spot in spots)
                          LineTooltipItem(
                            Money.format((spot.y * 100).round()),
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: colors.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: colors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _compactYuan(double value) {
    final absolute = value.abs();
    final sign = value < 0 ? '−' : '';
    if (absolute >= 10000) {
      return '$sign${(absolute / 10000).toStringAsFixed(1)}万';
    }
    return '$sign${absolute.round()}';
  }
}
