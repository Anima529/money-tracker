import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_dates.dart';
import '../../../core/utils/money.dart';
import '../domain/schedule.dart';
import '../providers/schedule_providers.dart';
import 'schedule_editor_sheet.dart';

Future<void> showScheduleManager(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const FractionallySizedBox(
        heightFactor: 0.9,
        child: ScheduleManagerSheet(),
      ),
    );

class ScheduleManagerSheet extends ConsumerWidget {
  const ScheduleManagerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('周期计划'),
      actions: [
        IconButton(
          tooltip: '新建计划',
          onPressed: () => showScheduleEditor(context),
          icon: const Icon(Icons.add_rounded),
        ),
        IconButton(
          tooltip: '关闭',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
    body: ref
        .watch(schedulesProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const Center(child: Text('计划加载失败')),
          data: (schedules) => schedules.isEmpty
              ? Center(
                  child: FilledButton.icon(
                    onPressed: () => showScheduleEditor(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('新建第一个周期计划'),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: schedules.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final schedule = schedules[index];
                    return Card(
                      child: ListTile(
                        onTap: () =>
                            showScheduleEditor(context, initial: schedule),
                        leading: Icon(
                          schedule.isEnabled
                              ? Icons.event_repeat_rounded
                              : Icons.event_busy_outlined,
                        ),
                        title: Text(schedule.title),
                        subtitle: Text(
                          '${_frequencyLabel(schedule)} · 下次 ${AppDates.dayLabel(schedule.nextDate)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(Money.format(schedule.amount)),
                            PopupMenuButton<String>(
                              onSelected: (action) async {
                                if (action == 'edit') {
                                  await showScheduleEditor(
                                    context,
                                    initial: schedule,
                                  );
                                } else if (action == 'delete') {
                                  await ref
                                      .read(scheduleRepositoryProvider)
                                      .delete(schedule.id);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: 'edit', child: Text('编辑')),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('删除'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
  );

  static String _frequencyLabel(Schedule schedule) {
    final unit = switch (schedule.frequency) {
      ScheduleFrequency.weekly => '周',
      ScheduleFrequency.monthly => '月',
      ScheduleFrequency.yearly => '年',
      ScheduleFrequency.custom => '天',
    };
    return schedule.interval == 1 ? '每$unit' : '每 ${schedule.interval} $unit';
  }
}
