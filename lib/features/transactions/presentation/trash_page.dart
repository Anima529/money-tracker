import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_dates.dart';
import '../../../shared/widgets/async_content.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/providers/account_providers.dart';
import '../domain/transaction.dart';
import '../providers/transaction_providers.dart';
import 'transaction_tile.dart';

class TrashPage extends ConsumerStatefulWidget {
  const TrashPage({super.key});

  @override
  ConsumerState<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends ConsumerState<TrashPage> {
  final _busyIds = <int>{};

  Future<void> _restore(Transaction transaction) async {
    if (!_begin(transaction.id)) return;
    try {
      final restored = await ref
          .read(transactionRepositoryProvider)
          .restore(transaction.id);
      if (!restored && mounted) _showError('账单已不存在');
    } on Object {
      if (mounted) _showError('恢复失败，请重试');
    } finally {
      _finish(transaction.id);
    }
  }

  Future<void> _permanentlyDelete(Transaction transaction) async {
    if (_busyIds.contains(transaction.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('永久删除这笔账单？'),
        content: const Text('删除后将无法恢复，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_begin(transaction.id)) return;
    try {
      final deleted = await ref
          .read(transactionRepositoryProvider)
          .permanentlyDelete(transaction.id);
      if (!deleted && mounted) _showError('账单已不存在');
    } on Object {
      if (mounted) _showError('永久删除失败，请重试');
    } finally {
      _finish(transaction.id);
    }
  }

  bool _begin(int id) {
    if (_busyIds.contains(id)) return false;
    setState(() => _busyIds.add(id));
    return true;
  }

  void _finish(int id) {
    if (mounted) setState(() => _busyIds.remove(id));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(accountsProvider).asData?.value ?? const <Account>[];
    return Scaffold(
      appBar: AppBar(title: const Text('回收站')),
      body: AsyncContent(
        value: ref.watch(trashTransactionsProvider),
        onRetry: () => ref.invalidate(trashTransactionsProvider),
        builder: (transactions) {
          if (transactions.isEmpty) {
            return const Center(
              child: EmptyState(title: '回收站是空的', message: '从时间线删除的账单会暂时保存在这里。'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            itemCount: transactions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              final busy = _busyIds.contains(transaction.id);
              final accountName =
                  accounts
                      .where((account) => account.id == transaction.accountId)
                      .firstOrNull
                      ?.name ??
                  '账户 #${transaction.accountId}';
              return Card(
                child: Column(
                  children: [
                    TransactionTile(
                      transaction: transaction,
                      subtitlePrefix:
                          '$accountName · ${AppDates.dayLabel(transaction.transactionDate)}',
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: busy
                                ? null
                                : () => _restore(transaction),
                            icon: const Icon(Icons.restore_rounded),
                            label: const Text('恢复'),
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            onPressed: busy
                                ? null
                                : () => _permanentlyDelete(transaction),
                            icon: busy
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.delete_forever_outlined),
                            label: const Text('永久删除'),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context)
                                  .colorScheme
                                  .error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
