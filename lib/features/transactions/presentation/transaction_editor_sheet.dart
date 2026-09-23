import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/amount_expression.dart';
import '../../../core/utils/app_dates.dart';
import '../../../core/utils/money.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/providers/account_providers.dart';
import '../../quick_input/domain/quick_input_parser.dart';
import '../../quick_input/providers/merchant_rule_providers.dart';
import '../../settings/providers/theme_provider.dart';
import '../data/transaction_preferences.dart';
import '../domain/transaction.dart';
import '../domain/transaction_category.dart';
import '../providers/transaction_providers.dart';

Future<bool?> showTransactionEditor(
  BuildContext context, {
  Transaction? initial,
  bool copy = false,
  TransactionType initialType = TransactionType.expense,
  TransactionDraft? initialDraft,
  String? title,
  TransactionStatus initialStatus = TransactionStatus.confirmed,
  DateTime? initialDate,
  bool showQuickInput = false,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => FractionallySizedBox(
    heightFactor: 0.96,
    child: TransactionEditorSheet(
      initial: initial,
      copy: copy,
      initialType: initialType,
      initialDraft: initialDraft,
      title: title,
      initialStatus: initialStatus,
      initialDate: initialDate,
      showQuickInput: showQuickInput,
    ),
  ),
);

class TransactionEditorSheet extends ConsumerStatefulWidget {
  const TransactionEditorSheet({
    super.key,
    this.initial,
    this.copy = false,
    this.initialType = TransactionType.expense,
    this.initialDraft,
    this.title,
    this.initialStatus = TransactionStatus.confirmed,
    this.initialDate,
    this.showQuickInput = false,
  });

  final Transaction? initial;
  final bool copy;
  final TransactionType initialType;
  final TransactionDraft? initialDraft;
  final String? title;
  final TransactionStatus initialStatus;
  final DateTime? initialDate;
  final bool showQuickInput;

  @override
  ConsumerState<TransactionEditorSheet> createState() =>
      _TransactionEditorSheetState();
}

class _TransactionEditorSheetState
    extends ConsumerState<TransactionEditorSheet> {
  late TransactionType _type;
  late String _expression;
  late DateTime _date;
  late String _category;
  int? _accountId;
  int? _transferAccountId;
  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;
  late final TextEditingController _noteController;
  late final TextEditingController _quickInputController;
  TransactionStatus _newStatus = TransactionStatus.confirmed;
  QuickInputResult? _quickResult;
  late bool _showQuickInput;
  bool _selectionInitialized = false;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.initial != null && !widget.copy;

  @override
  void initState() {
    super.initState();
    _showQuickInput = widget.showQuickInput;
    final initial = widget.initial;
    final draft = widget.initialDraft;
    _type = initial?.type ?? draft?.type ?? widget.initialType;
    _expression = initial != null
        ? _plainAmount(initial.amount)
        : draft != null
        ? _plainAmount(draft.amount)
        : '';
    _amountController = TextEditingController(text: _expression);
    _date =
        initial?.transactionDate ??
        draft?.transactionDate ??
        widget.initialDate ??
        DateTime.now();
    _category = initial?.category ?? draft?.category ?? _defaultCategory(_type);
    _accountId = initial?.accountId ?? draft?.accountId;
    _transferAccountId = initial?.transferAccountId ?? draft?.transferAccountId;
    _newStatus = draft?.status ?? widget.initialStatus;
    _merchantController = TextEditingController(
      text: initial?.merchant ?? draft?.merchant ?? '',
    );
    _noteController = TextEditingController(
      text: initial?.note ?? draft?.note ?? '',
    );
    _quickInputController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    _quickInputController.dispose();
    super.dispose();
  }

  static String _plainAmount(int cents) {
    final whole = cents ~/ 100;
    final fraction = cents % 100;
    return fraction == 0
        ? '$whole'
        : '$whole.${fraction.toString().padLeft(2, '0')}';
  }

  static String _defaultCategory(TransactionType type) => switch (type) {
    TransactionType.income => 'salary',
    TransactionType.expense => 'food',
    TransactionType.transfer => 'transfer',
  };

  void _initializeSelection(List<Account> accounts) {
    if (_selectionInitialized || accounts.isEmpty) return;
    _selectionInitialized = true;
    final preferences = TransactionPreferences(ref.read(preferencesProvider));
    final accountIds = accounts.map((account) => account.id).toSet();
    _accountId = accountIds.contains(_accountId)
        ? _accountId
        : accountIds.contains(preferences.recentAccountId)
        ? preferences.recentAccountId
        : accounts.first.id;
    if (_type != TransactionType.transfer &&
        widget.initial == null &&
        widget.initialDraft == null) {
      final recent = preferences.recentCategory(_type);
      if (Categories.all.any(
        (category) => category.id == recent && category.type == _type,
      )) {
        _category = recent!;
      }
    }
    if (_type == TransactionType.transfer) {
      _transferAccountId =
          accountIds.contains(_transferAccountId) &&
              _transferAccountId != _accountId
          ? _transferAccountId
          : accounts
                .where((account) => account.id != _accountId)
                .firstOrNull
                ?.id;
    }
  }

  void _changeType(TransactionType type, List<Account> accounts) {
    if (_saving || type == _type) return;
    final preferences = TransactionPreferences(ref.read(preferencesProvider));
    setState(() {
      _type = type;
      _category = type == TransactionType.transfer
          ? 'transfer'
          : preferences.recentCategory(type) ?? _defaultCategory(type);
      if (!Categories.all.any(
        (category) => category.id == _category && category.type == type,
      )) {
        _category = _defaultCategory(type);
      }
      _transferAccountId = type == TransactionType.transfer
          ? accounts
                .where((account) => account.id != _accountId)
                .firstOrNull
                ?.id
          : null;
      _error = null;
    });
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('zh', 'CN'),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _save(List<Account> accounts) async {
    // _saving 在任何 await 之前置位，连续点击只会发起一次写入。
    if (_saving) return;
    int amount;
    try {
      amount = AmountExpression.evaluate(_expression);
      if (_accountId == null) throw const FormatException('请选择账户');
      if (_type == TransactionType.transfer &&
          (_transferAccountId == null || _transferAccountId == _accountId)) {
        throw const FormatException('请选择不同的转出和转入账户');
      }
    } on FormatException catch (error) {
      setState(() => _error = error.message);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final original = widget.initial;
      final draft = TransactionDraft(
        type: _type,
        amount: amount,
        category: _type == TransactionType.transfer ? 'transfer' : _category,
        accountId: _accountId!,
        transferAccountId: _type == TransactionType.transfer
            ? _transferAccountId
            : null,
        status: _editing ? original!.status : _newStatus,
        source: _editing
            ? original!.source
            : widget.initialDraft?.source ?? TransactionSource.manual,
        merchant: _merchantController.text,
        confidence: _editing ? original!.confidence : null,
        scheduleId: _editing
            ? original!.scheduleId
            : widget.initialDraft?.scheduleId,
        scheduledFor: _editing
            ? original!.scheduledFor
            : widget.initialDraft?.scheduledFor,
        sourceFingerprint: _editing ? original!.sourceFingerprint : null,
        confirmedAt: _editing ? original!.confirmedAt : null,
        note: _noteController.text,
        transactionDate: _date,
      );
      final repository = ref.read(transactionRepositoryProvider);
      final success = _editing
          ? await repository.update(original!.id, draft)
          : await repository.add(draft) > 0;
      if (!success) throw StateError('账单不存在或已被删除');
      // 最近选择只是便捷偏好；保存失败不能让已经入库的账单被重复提交。
      try {
        await TransactionPreferences(ref.read(preferencesProvider)).remember(
          accountId: _accountId!,
          type: _type,
          category: draft.category,
        );
      } on Object {
        // 交易本身已经成功，保持主流程可完成。
      }
      if (_quickResult?.merchant != null && _type != TransactionType.transfer) {
        try {
          await ref
              .read(merchantRuleRepositoryProvider)
              .learn(
                pattern: _quickResult!.merchant!,
                category: draft.category,
                accountId: draft.accountId,
                merchant: _merchantController.text,
              );
        } on Object {
          // 学习规则失败不影响已经保存的交易。
        }
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

  Future<void> _parseQuickInput(List<Account> accounts) async {
    final text = _quickInputController.text.trim();
    if (text.isEmpty) return;
    final rules = await ref.read(merchantRuleRepositoryProvider).getAll();
    final result = const QuickInputParser().parse(
      text,
      now: DateTime.now(),
      accounts: accounts,
      rules: rules,
    );
    if (!mounted) return;
    setState(() {
      _quickResult = result;
      _type = result.type;
      _category = result.category;
      _date = result.date;
      _newStatus = result.status;
      if (result.amount != null) {
        _expression = _plainAmount(result.amount!);
        _amountController.text = _expression;
      }
      if (result.accountId != null &&
          accounts.any((account) => account.id == result.accountId)) {
        _accountId = result.accountId;
      }
      if (result.merchant != null) _merchantController.text = result.merchant!;
      _error = result.hasAmount ? null : '未识别到金额，请在金额输入框中填写';
    });
  }

  @override
  Widget build(BuildContext context) {
    final accountsValue = ref.watch(accountsProvider);
    return accountsValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: FilledButton.tonal(
          onPressed: () => ref.invalidate(accountsProvider),
          child: const Text('账户加载失败，点击重试'),
        ),
      ),
      data: (accounts) {
        _initializeSelection(accounts);
        final categories = Categories.all
            .where((category) => category.type == _type)
            .toList(growable: false);
        final preview = AmountExpression.preview(_expression);
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(
              widget.title ??
                  (_editing
                      ? '编辑账单'
                      : widget.copy
                      ? '复制账单'
                      : '记一笔'),
            ),
            actions: [
              IconButton(
                tooltip: '一句话快速记账',
                onPressed: _saving
                    ? null
                    : () => setState(() => _showQuickInput = !_showQuickInput),
                icon: const Icon(Icons.auto_awesome_outlined),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          body: accounts.isEmpty
              ? const Center(child: Text('请先创建一个可用账户'))
              : ListView(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    if (_showQuickInput) ...[
                      TextField(
                        controller: _quickInputController,
                        enabled: !_saving,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _parseQuickInput(accounts),
                        decoration: InputDecoration(
                          labelText: '一句话快速记账',
                          hintText: '例如：瑞幸 16 微信',
                          prefixIcon: const Icon(Icons.auto_awesome_outlined),
                          suffixIcon: IconButton(
                            tooltip: '识别',
                            onPressed: _saving
                                ? null
                                : () => _parseQuickInput(accounts),
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ),
                      ),
                      if (_quickResult != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final explanation
                                in _quickResult!.explanations)
                              Chip(label: Text(explanation)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
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
                      onSelectionChanged: (selection) =>
                          _changeType(selection.single, accounts),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('transaction_amount_input'),
                      controller: _amountController,
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(64),
                        const _AmountExpressionFormatter(),
                      ],
                      textInputAction: TextInputAction.done,
                      onChanged: (value) => setState(() {
                        _expression = value;
                        _error = null;
                      }),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                      textAlign: TextAlign.end,
                      decoration: InputDecoration(
                        labelText: '金额',
                        hintText: '0.00',
                        hintStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.38),
                          fontWeight: FontWeight.w400,
                        ),
                        prefixText: '¥ ',
                        prefixStyle: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w400,
                            ),
                        helperText:
                            '合计 ${preview == null ? '¥0.00' : Money.format(preview)}',
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: _accountId,
                      decoration: InputDecoration(
                        labelText: _type == TransactionType.transfer
                            ? '转出账户'
                            : '账户',
                        prefixIcon: const Icon(
                          Icons.account_balance_wallet_outlined,
                        ),
                      ),
                      items: [
                        for (final account in accounts)
                          DropdownMenuItem(
                            value: account.id,
                            child: Text(account.name),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              _accountId = value;
                              if (_transferAccountId == value) {
                                _transferAccountId = accounts
                                    .where((account) => account.id != value)
                                    .firstOrNull
                                    ?.id;
                              }
                            }),
                    ),
                    if (_type == TransactionType.transfer) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _transferAccountId,
                        decoration: const InputDecoration(
                          labelText: '转入账户',
                          prefixIcon: Icon(Icons.move_down_rounded),
                        ),
                        items: [
                          for (final account in accounts.where(
                            (account) => account.id != _accountId,
                          ))
                            DropdownMenuItem(
                              value: account.id,
                              child: Text(account.name),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) =>
                                  setState(() => _transferAccountId = value),
                      ),
                      if (accounts.length < 2)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('转账至少需要两个账户'),
                        ),
                    ] else ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue:
                            categories.any((item) => item.id == _category)
                            ? _category
                            : categories.first.id,
                        decoration: const InputDecoration(
                          labelText: '分类',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: [
                          for (final category in categories)
                            DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _category = value!),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          leading: const Icon(Icons.calendar_today_outlined),
                          title: const Text('日期'),
                          trailing: Text(AppDates.dayLabel(_date)),
                          onTap: _saving ? null : _pickDate,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _merchantController,
                      enabled: !_saving,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: '商户（可选）',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _noteController,
                      enabled: !_saving,
                      maxLength: 1000,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: '备注（可选）',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
          bottomNavigationBar: accounts.isEmpty
              ? null
              : SafeArea(
                  minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: FilledButton.icon(
                    onPressed:
                        _saving ||
                            (_type == TransactionType.transfer &&
                                accounts.length < 2)
                        ? null
                        : () => _save(accounts),
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(_saving ? '保存中…' : '保存'),
                  ),
                ),
        );
      },
    );
  }
}

class _AmountExpressionFormatter extends TextInputFormatter {
  const _AmountExpressionFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Keep incomplete operators valid while typing; saving still uses
    // AmountExpression for the final amount and range validation.
    return RegExp(r'^\d*(?:\.\d{0,2})?(?:[+-]\d*(?:\.\d{0,2})?)*$')
            .hasMatch(newValue.text)
        ? newValue
        : oldValue;
  }
}
