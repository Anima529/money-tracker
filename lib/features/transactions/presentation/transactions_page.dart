import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_dates.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/async_content.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/providers/account_providers.dart';
import '../../cash_flow/presentation/cash_flow_widgets.dart';
import '../domain/transaction.dart';
import '../domain/transaction_category.dart';
import '../providers/transaction_providers.dart';
import 'transaction_detail_sheet.dart';
import 'transaction_tile.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final _searchController = TextEditingController();
  TransactionType? _type;
  String? _category;
  int? _accountId;
  DateTimeRange? _dateRange;

  bool get _hasFilters =>
      _searchController.text.trim().isNotEmpty ||
      _type != null ||
      _category != null ||
      _accountId != null ||
      _dateRange != null;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _type = null;
      _category = null;
      _accountId = null;
      _dateRange = null;
    });
  }

  Future<void> _pickDateRange() async {
    final selected = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      currentDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );
    if (selected != null && mounted) setState(() => _dateRange = selected);
  }

  List<Transaction> _filter(
    List<Transaction> transactions,
    List<Account> accounts,
  ) {
    final keyword = _searchController.text.trim().toLowerCase();
    final accountNames = {
      for (final account in accounts) account.id: account.name,
    };
    return transactions
        .where((transaction) {
          if (_type != null && transaction.type != _type) {
            return false;
          }
          if (_category != null && transaction.category != _category) {
            return false;
          }
          if (_accountId != null &&
              transaction.accountId != _accountId &&
              transaction.transferAccountId != _accountId) {
            return false;
          }
          if (_dateRange != null) {
            final day = AppDates.dayStart(transaction.transactionDate);
            if (day.isBefore(AppDates.dayStart(_dateRange!.start)) ||
                day.isAfter(AppDates.dayStart(_dateRange!.end))) {
              return false;
            }
          }
          if (keyword.isNotEmpty) {
            final category = Categories.find(transaction.category)?.name ?? '';
            final searchable = [
              category,
              transaction.merchant ?? '',
              transaction.note,
              accountNames[transaction.accountId] ?? '',
              accountNames[transaction.transferAccountId] ?? '',
            ].join(' ').toLowerCase();
            if (!searchable.contains(keyword)) {
              return false;
            }
          }
          return true;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const <Account>[];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: SearchBar(
            controller: _searchController,
            hintText: '搜索分类、商户、备注或账户',
            leading: const Icon(Icons.search_rounded),
            trailing: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  tooltip: '清空关键词',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
            onChanged: (_) => setState(() {}),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _TypeFilterChip(
                value: _type,
                onChanged: (value) => setState(() {
                  _type = value;
                  if (value == TransactionType.transfer ||
                      (value != null &&
                          Categories.find(_category ?? '')?.type != value)) {
                    _category = null;
                  }
                }),
              ),
              const SizedBox(width: 8),
              _MenuFilterChip<String>(
                label: _category == null
                    ? '分类'
                    : Categories.find(_category!)?.name ?? '分类',
                selected: _category != null,
                values: [
                  for (final category in Categories.all.where(
                    (category) => _type == null || category.type == _type,
                  ))
                    (category.id, category.name),
                ],
                onSelected: (value) => setState(() => _category = value),
                onClear: () => setState(() => _category = null),
              ),
              const SizedBox(width: 8),
              _MenuFilterChip<int>(
                label: _accountId == null
                    ? '账户'
                    : accounts
                              .where((account) => account.id == _accountId)
                              .firstOrNull
                              ?.name ??
                          '账户',
                selected: _accountId != null,
                values: [
                  for (final account in accounts) (account.id, account.name),
                ],
                onSelected: (value) => setState(() => _accountId = value),
                onClear: () => setState(() => _accountId = null),
              ),
              const SizedBox(width: 8),
              FilterChip(
                selected: _dateRange != null,
                label: Text(
                  _dateRange == null
                      ? '日期'
                      : '${AppDates.dayLabel(_dateRange!.start)}–${AppDates.dayLabel(_dateRange!.end)}',
                ),
                avatar: const Icon(Icons.date_range_outlined, size: 18),
                onSelected: (selected) {
                  if (selected) {
                    _pickDateRange();
                  } else {
                    setState(() => _dateRange = null);
                  }
                },
              ),
              if (_hasFilters) ...[
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text('重置'),
                  onPressed: _clearFilters,
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: AsyncContent(
            value: ref.watch(transactionsProvider),
            onRetry: () => ref.invalidate(transactionsProvider),
            builder: (transactions) {
              final filtered = _filter(transactions, accounts);
              if (transactions.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
                  children: const [
                    FutureCashFlowList(),
                    EmptyState(
                      title: '还没有已确认账单',
                      message: '确认计划或记下一笔后，会显示在历史记录中。',
                    ),
                  ],
                );
              }
              if (filtered.isEmpty) {
                return Center(
                  child: EmptyState(
                    title: '没有匹配的账单',
                    message: '换个关键词或筛选条件试试。',
                    actionLabel: '重置筛选',
                    onAction: _clearFilters,
                  ),
                );
              }
              final groups = <DateTime, List<Transaction>>{};
              for (final transaction in filtered) {
                groups
                    .putIfAbsent(
                      AppDates.dayStart(transaction.transactionDate),
                      () => [],
                    )
                    .add(transaction);
              }
              final children = <Widget>[const FutureCashFlowList()];
              for (final entry in groups.entries) {
                final expense = entry.value
                    .where((item) => item.type == TransactionType.expense)
                    .fold<int>(0, (sum, item) => sum + item.amount);
                final income = entry.value
                    .where((item) => item.type == TransactionType.income)
                    .fold<int>(0, (sum, item) => sum + item.amount);
                children.add(
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            AppDates.dayLabel(entry.key),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          '收 ${_compactAmount(income)}  支 ${_compactAmount(expense)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
                for (final transaction in entry.value) {
                  final accountName =
                      accounts
                          .where(
                            (account) => account.id == transaction.accountId,
                          )
                          .firstOrNull
                          ?.name ??
                      '账户 #${transaction.accountId}';
                  children.add(
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: TransactionTile(
                          transaction: transaction,
                          subtitlePrefix: accountName,
                          onTap: () =>
                              showTransactionDetail(context, transaction),
                        ),
                      ),
                    ),
                  );
                }
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
                children: children,
              );
            },
          ),
        ),
      ],
    );
  }

  static String _compactAmount(int cents) => Money.format(cents, symbol: false);
}

class _TypeFilterChip extends StatelessWidget {
  const _TypeFilterChip({required this.value, required this.onChanged});

  final TransactionType? value;
  final ValueChanged<TransactionType?> onChanged;

  @override
  Widget build(BuildContext context) => PopupMenuButton<TransactionType>(
    tooltip: '筛选类型',
    onSelected: onChanged,
    itemBuilder: (context) => const [
      PopupMenuItem(value: TransactionType.expense, child: Text('支出')),
      PopupMenuItem(value: TransactionType.income, child: Text('收入')),
      PopupMenuItem(value: TransactionType.transfer, child: Text('转账')),
    ],
    child: InputChip(
      selected: value != null,
      label: Text(switch (value) {
        TransactionType.expense => '支出',
        TransactionType.income => '收入',
        TransactionType.transfer => '转账',
        null => '类型',
      }),
      avatar: const Icon(Icons.swap_vert_rounded, size: 18),
      onPressed: null,
      onDeleted: value == null ? null : () => onChanged(null),
    ),
  );
}

class _MenuFilterChip<T> extends StatelessWidget {
  const _MenuFilterChip({
    required this.label,
    required this.selected,
    required this.values,
    required this.onSelected,
    required this.onClear,
  });

  final String label;
  final bool selected;
  final List<(T, String)> values;
  final ValueChanged<T> onSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
    tooltip: '筛选$label',
    onSelected: onSelected,
    itemBuilder: (context) => [
      for (final value in values)
        PopupMenuItem(value: value.$1, child: Text(value.$2)),
    ],
    child: InputChip(
      selected: selected,
      label: Text(label),
      onPressed: null,
      onDeleted: selected ? onClear : null,
    ),
  );
}
