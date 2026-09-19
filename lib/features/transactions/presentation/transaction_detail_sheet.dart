import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_dates.dart';
import '../../../core/utils/money.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/providers/account_providers.dart';
import '../domain/transaction.dart';
import '../domain/transaction_category.dart';
import '../providers/transaction_providers.dart';
import 'transaction_editor_sheet.dart';

Future<void> showTransactionDetail(
  BuildContext context,
  Transaction transaction,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => TransactionDetailSheet(transaction: transaction),
);

class TransactionDetailSheet extends ConsumerStatefulWidget {
  const TransactionDetailSheet({super.key, required this.transaction});

  final Transaction transaction;

  @override
  ConsumerState<TransactionDetailSheet> createState() =>
      _TransactionDetailSheetState();
}

class _TransactionDetailSheetState
    extends ConsumerState<TransactionDetailSheet> {
  bool _deleting = false;

  Future<void> _delete() async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这笔账单？'),
        content: const Text('删除后可在底部提示中立即撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    final repository = ref.read(transactionRepositoryProvider);
    final deleted = await repository.delete(widget.transaction.id);
    if (!mounted) return;
    if (!deleted) {
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('账单已不存在')));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('账单已删除'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () async {
            try {
              await repository.restore(widget.transaction);
            } on Object {
              messenger.showSnackBar(
                const SnackBar(content: Text('撤销失败，请重新记一笔')),
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final category = Categories.find(transaction.category);
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const <Account>[];
    String accountName(int? id) =>
        accounts.where((account) => account.id == id).firstOrNull?.name ??
        '账户 #$id';
    final sign = switch (transaction.type) {
      TransactionType.income => '+',
      TransactionType.expense => '−',
      TransactionType.transfer => '',
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            transaction.type == TransactionType.transfer
                ? '转账'
                : category?.name ?? '未分类',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '$sign${Money.format(transaction.amount)}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 20),
          _DetailRow(
            label: '日期',
            value: AppDates.dayLabel(transaction.transactionDate),
          ),
          _DetailRow(
            label: transaction.type == TransactionType.transfer ? '转出账户' : '账户',
            value: accountName(transaction.accountId),
          ),
          if (transaction.type == TransactionType.transfer)
            _DetailRow(
              label: '转入账户',
              value: accountName(transaction.transferAccountId),
            ),
          if (transaction.merchant != null)
            _DetailRow(label: '商户', value: transaction.merchant!),
          if (transaction.note.isNotEmpty)
            _DetailRow(label: '备注', value: transaction.note),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _deleting
                      ? null
                      : () async {
                          final navigator = Navigator.of(context);
                          final editorContext = navigator.context;
                          navigator.pop();
                          await showTransactionEditor(
                            editorContext,
                            initial: transaction,
                            copy: true,
                          );
                        },
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('复制'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _deleting
                      ? null
                      : () async {
                          final navigator = Navigator.of(context);
                          final editorContext = navigator.context;
                          navigator.pop();
                          await showTransactionEditor(
                            editorContext,
                            initial: transaction,
                          );
                        },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('编辑'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _deleting ? null : _delete,
            icon: _deleting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            label: const Text('删除账单'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
