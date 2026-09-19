import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/amount_expression.dart';
import '../../../core/utils/app_dates.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/providers/account_providers.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/domain/transaction_category.dart';
import '../../transactions/providers/transaction_providers.dart';
import '../domain/schedule.dart';
import '../providers/schedule_providers.dart';

Future<bool?> showScheduleEditor(
  BuildContext context, {
  Schedule? initial,
  DateTime? effectiveFrom,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => FractionallySizedBox(
    heightFactor: 0.94,
    child: ScheduleEditorSheet(initial: initial, effectiveFrom: effectiveFrom),
  ),
);

class ScheduleEditorSheet extends ConsumerStatefulWidget {
  const ScheduleEditorSheet({super.key, this.initial, this.effectiveFrom});

  final Schedule? initial;

  /// 从指定实例开始修改；较晚的实例会拆分为新旧两条规则。
  final DateTime? effectiveFrom;

  @override
  ConsumerState<ScheduleEditorSheet> createState() =>
      _ScheduleEditorSheetState();
}

class _ScheduleEditorSheetState extends ConsumerState<ScheduleEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _intervalController;
  late TransactionType _type;
  late String _category;
  int? _accountId;
  int? _transferAccountId;
  late ScheduleFrequency _frequency;
  late DateTime _startDate;
  DateTime? _endDate;
  late bool _isEssential;
  late bool _isEnabled;
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final effective = widget.effectiveFrom == null
        ? null
        : AppDates.dayStart(widget.effectiveFrom!);
    _titleController = TextEditingController(text: initial?.title ?? '');
    _amountController = TextEditingController(
      text: initial == null ? '' : _plainAmount(initial.amount),
    );
    _intervalController = TextEditingController(
      text: '${initial?.interval ?? 1}',
    );
    _type = initial?.type ?? TransactionType.expense;
    _category = initial?.category ?? 'housing';
    _accountId = initial?.accountId;
    _transferAccountId = initial?.transferAccountId;
    _frequency = initial?.frequency ?? ScheduleFrequency.monthly;
    _startDate =
        effective ??
        initial?.startDate ??
        DateTime.now().add(const Duration(days: 1));
    _endDate = initial?.endDate;
    _isEssential = initial?.isEssential ?? true;
    _isEnabled = initial?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  static String _plainAmount(int cents) =>
      '${cents ~/ 100}${cents % 100 == 0 ? '' : '.${(cents % 100).toString().padLeft(2, '0')}'}';

  void _initializeAccounts(List<Account> accounts) {
    if (_initialized || accounts.isEmpty) return;
    _initialized = true;
    if (!accounts.any((account) => account.id == _accountId)) {
      _accountId = accounts.first.id;
    }
    if (_type == TransactionType.transfer &&
        (!accounts.any((account) => account.id == _transferAccountId) ||
            _transferAccountId == _accountId)) {
      _transferAccountId = accounts
          .where((item) => item.id != _accountId)
          .firstOrNull
          ?.id;
    }
  }

  Future<void> _pickStart() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) setState(() => _startDate = selected);
  }

  Future<void> _pickEnd() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) setState(() => _endDate = selected);
  }

  ScheduleDraft _draft({required DateTime start, required DateTime next}) =>
      ScheduleDraft(
        title: _titleController.text,
        type: _type,
        amount: AmountExpression.evaluate(_amountController.text),
        category: _type == TransactionType.transfer ? 'transfer' : _category,
        accountId: _accountId!,
        transferAccountId: _type == TransactionType.transfer
            ? _transferAccountId
            : null,
        frequency: _frequency,
        interval: int.parse(_intervalController.text),
        startDate: start,
        nextDate: next,
        endDate: _endDate,
        isEssential: _type == TransactionType.expense && _isEssential,
        isEnabled: _isEnabled,
      );

  Future<void> _save(List<Account> accounts) async {
    if (_saving) return;
    try {
      if (_titleController.text.trim().isEmpty) {
        throw const FormatException('请输入计划名称');
      }
      if (_accountId == null) throw const FormatException('请选择账户');
      final interval = int.tryParse(_intervalController.text);
      if (interval == null || interval < 1) {
        throw const FormatException('间隔必须大于 0');
      }
      if (_type == TransactionType.transfer &&
          (_transferAccountId == null || _transferAccountId == _accountId)) {
        throw const FormatException('转账需要两个不同账户');
      }
      AmountExpression.evaluate(_amountController.text);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = ref.read(scheduleRepositoryProvider);
      final initial = widget.initial;
      final effective = widget.effectiveFrom == null
          ? null
          : AppDates.dayStart(widget.effectiveFrom!);
      if (initial == null) {
        await repository.add(_draft(start: _startDate, next: _startDate));
      } else if (effective != null && effective.isAfter(initial.nextDate)) {
        final database = ref.read(databaseProvider);
        await database.transaction(() async {
          await repository.update(
            initial.id,
            ScheduleDraft(
              title: initial.title,
              type: initial.type,
              amount: initial.amount,
              category: initial.category,
              accountId: initial.accountId,
              transferAccountId: initial.transferAccountId,
              frequency: initial.frequency,
              interval: initial.interval,
              startDate: initial.startDate,
              nextDate: initial.nextDate,
              endDate: DateTime(
                effective.year,
                effective.month,
                effective.day - 1,
              ),
              isEssential: initial.isEssential,
              isEnabled: initial.isEnabled,
            ),
          );
          await repository.add(_draft(start: effective, next: effective));
        });
      } else {
        final start = effective ?? initial.startDate;
        final next = effective ?? initial.nextDate;
        await repository.update(initial.id, _draft(start: start, next: next));
      }
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is ArgumentError
              ? error.message?.toString()
              : '保存失败，请重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(accountsProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const Center(child: Text('账户加载失败')),
        data: (accounts) {
          _initializeAccounts(accounts);
          final categories = Categories.all
              .where((item) => item.type == _type)
              .toList();
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text(widget.initial == null ? '新建周期计划' : '修改周期计划'),
              actions: [
                IconButton(
                  tooltip: '关闭',
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                TextField(
                  controller: _titleController,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: '计划名称'),
                ),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '金额',
                    prefixText: '¥ ',
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: Text('支出'),
                    ),
                    ButtonSegment(
                      value: TransactionType.income,
                      label: Text('收入'),
                    ),
                    ButtonSegment(
                      value: TransactionType.transfer,
                      label: Text('转账'),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (value) => setState(() {
                    _type = value.single;
                    _category = _type == TransactionType.income
                        ? 'salary'
                        : 'housing';
                    _transferAccountId = _type == TransactionType.transfer
                        ? accounts
                              .where((item) => item.id != _accountId)
                              .firstOrNull
                              ?.id
                        : null;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _accountId,
                  decoration: InputDecoration(
                    labelText: _type == TransactionType.transfer
                        ? '转出账户'
                        : '账户',
                  ),
                  items: [
                    for (final account in accounts)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(account.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _accountId = value),
                ),
                if (_type == TransactionType.transfer) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _transferAccountId,
                    decoration: const InputDecoration(labelText: '转入账户'),
                    items: [
                      for (final account in accounts.where(
                        (item) => item.id != _accountId,
                      ))
                        DropdownMenuItem(
                          value: account.id,
                          child: Text(account.name),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _transferAccountId = value),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: categories.any((item) => item.id == _category)
                        ? _category
                        : categories.first.id,
                    decoration: const InputDecoration(labelText: '分类'),
                    items: [
                      for (final category in categories)
                        DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _category = value!),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<ScheduleFrequency>(
                  initialValue: _frequency,
                  decoration: const InputDecoration(labelText: '频率'),
                  items: const [
                    DropdownMenuItem(
                      value: ScheduleFrequency.weekly,
                      child: Text('每周'),
                    ),
                    DropdownMenuItem(
                      value: ScheduleFrequency.monthly,
                      child: Text('每月'),
                    ),
                    DropdownMenuItem(
                      value: ScheduleFrequency.yearly,
                      child: Text('每年'),
                    ),
                    DropdownMenuItem(
                      value: ScheduleFrequency.custom,
                      child: Text('自定义天数'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _frequency = value!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _intervalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '每隔几个周期执行'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('开始日期'),
                  trailing: Text(AppDates.dayLabel(_startDate)),
                  onTap: widget.effectiveFrom == null ? _pickStart : null,
                ),
                ListTile(
                  leading: const Icon(Icons.event_busy_outlined),
                  title: const Text('结束日期'),
                  trailing: Text(
                    _endDate == null ? '不设结束' : AppDates.dayLabel(_endDate!),
                  ),
                  onTap: _pickEnd,
                ),
                if (_endDate != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => _endDate = null),
                      child: const Text('清除结束日期'),
                    ),
                  ),
                if (_type == TransactionType.expense)
                  SwitchListTile(
                    value: _isEssential,
                    onChanged: (value) => setState(() => _isEssential = value),
                    title: const Text('必要支出'),
                    subtitle: const Text('参与“安心可花”的预留计算'),
                  ),
                SwitchListTile(
                  value: _isEnabled,
                  onChanged: (value) => setState(() => _isEnabled = value),
                  title: const Text('启用计划'),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: FilledButton.icon(
                onPressed: _saving || accounts.isEmpty
                    ? null
                    : () => _save(accounts),
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_saving ? '保存中…' : '保存计划'),
              ),
            ),
          );
        },
      );
}
