import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/amount_expression.dart';
import '../../../core/utils/money.dart';
import '../../quick_input/providers/merchant_rule_providers.dart';
import '../providers/safety_buffer_provider.dart';
import '../providers/theme_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final safetyBuffer = ref.watch(safetyBufferProvider);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('外观', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('选择让你舒服的显示方式'),
        const SizedBox(height: 20),
        Card(
          child: RadioGroup<ThemeMode>(
            groupValue: mode,
            onChanged: (value) async {
              if (value == null) return;
              try {
                await ref.read(themeModeProvider.notifier).setMode(value);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('主题保存失败，请重试')));
                }
              }
            },
            child: const Column(
              children: [
                RadioListTile(
                  value: ThemeMode.system,
                  title: Text('跟随系统'),
                  secondary: Icon(Icons.brightness_auto_outlined),
                ),
                RadioListTile(
                  value: ThemeMode.light,
                  title: Text('浅色'),
                  secondary: Icon(Icons.light_mode_outlined),
                ),
                RadioListTile(
                  value: ThemeMode.dark,
                  title: Text('深色'),
                  secondary: Icon(Icons.dark_mode_outlined),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text('现金流', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.health_and_safety_outlined),
            title: const Text('安全垫'),
            subtitle: const Text('从安心可花中额外预留'),
            trailing: Text(Money.format(safetyBuffer)),
            onTap: () => _editSafetyBuffer(context, ref, safetyBuffer),
          ),
        ),
        const SizedBox(height: 28),
        Text('快速输入规则', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: ref
              .watch(merchantRulesProvider)
              .when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) => const ListTile(title: Text('规则加载失败')),
                data: (rules) => rules.isEmpty
                    ? const ListTile(
                        leading: Icon(Icons.auto_awesome_outlined),
                        title: Text('暂无商户规则'),
                        subtitle: Text('使用一句话记账并确认分类后，规则会保存在本机。'),
                      )
                    : Column(
                        children: [
                          for (final rule in rules)
                            ListTile(
                              title: Text(rule.merchant ?? rule.pattern),
                              subtitle: Text('已使用 ${rule.useCount} 次'),
                              trailing: IconButton(
                                tooltip: '删除规则',
                                onPressed: () => ref
                                    .read(merchantRuleRepositoryProvider)
                                    .delete(rule.id),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ),
                          TextButton(
                            onPressed: () => ref
                                .read(merchantRuleRepositoryProvider)
                                .clear(),
                            child: const Text('清除全部规则'),
                          ),
                        ],
                      ),
              ),
        ),
        const SizedBox(height: 32),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.phonelink_lock_outlined),
                SizedBox(height: 12),
                Text(
                  '你的账本，留在本机',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text('无需账号。账单与偏好设置保存在手机本地。'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _editSafetyBuffer(
  BuildContext context,
  WidgetRef ref,
  int current,
) async {
  final controller = TextEditingController(
    text:
        '${current ~/ 100}${current % 100 == 0 ? '' : '.${(current % 100).toString().padLeft(2, '0')}'}',
  );
  String? error;
  final value = await showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('设置安全垫'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(prefixText: '¥ ', errorText: error),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              try {
                final cents = controller.text.trim() == '0'
                    ? 0
                    : AmountExpression.evaluate(controller.text);
                Navigator.of(context).pop(cents);
              } on FormatException catch (exception) {
                setState(() => error = exception.message);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  if (value != null) {
    await ref.read(safetyBufferProvider.notifier).setValue(value);
  }
}
