import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../settings/providers/safety_buffer_provider.dart';
import '../settings/providers/theme_provider.dart';
import '../transactions/providers/transaction_providers.dart';
import 'backup_service.dart';

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    ref.watch(databaseProvider),
    ref.watch(preferencesProvider),
  ),
);

class BackupControls extends ConsumerStatefulWidget {
  const BackupControls({super.key});

  @override
  ConsumerState<BackupControls> createState() => _BackupControlsState();
}

class _BackupControlsState extends ConsumerState<BackupControls> {
  static const _files = MethodChannel('money_tracker/backup_files');
  bool _busy = false;

  String _fileName(String prefix) =>
      'money-tracker-$prefix-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.zip';

  Future<bool> _save(Uint8List bytes, String name) async =>
      await _files.invokeMethod<bool>('save', {'bytes': bytes, 'name': name}) ==
      true;

  void _error(Object error) {
    final message = switch (error) {
      BackupException(:final message) => message,
      PlatformException(:final message) => message ?? '文件操作失败',
      _ => '操作失败，请检查备份文件和存储空间',
    };
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await ref.read(backupServiceProvider).export();
      final saved = await _save(bytes, _fileName('backup'));
      if (!saved) return;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('备份已保存')));
      }
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _files.invokeMethod<Uint8List>('open');
      if (bytes == null || !mounted) return;
      final service = ref.read(backupServiceProvider);
      final document = service.inspect(bytes);
      final mode = await showDialog<RestoreMode>(
        context: context,
        builder: (context) => _RestorePreviewDialog(preview: document.preview),
      );
      if (mode == null || !mounted) return;
      // Always give the user a portable snapshot before changing any rows.
      final snapshot = await service.export();
      final saved = await _save(snapshot, _fileName('before-restore'));
      if (!saved) return;
      final preferencesRestored = await service.restore(document, mode);
      ref.invalidate(themeModeProvider);
      ref.invalidate(safetyBufferProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              preferencesRestored
                  ? '账本已恢复，原来的账本副本也已保存'
                  : '账本已恢复，但部分设置未能保存；原来的账本副本已保存',
            ),
          ),
        );
      }
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.save_alt_rounded),
            title: const Text('导出备份'),
            subtitle: const Text('将当前账本保存为文件'),
            trailing: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _busy ? null : _export,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.restore_rounded),
            title: const Text('从文件恢复'),
            subtitle: const Text('先查看备份内容，再选择如何恢复'),
            onTap: _busy ? null : _import,
          ),
        ],
      ),
    );
  }
}

class _RestorePreviewDialog extends StatelessWidget {
  const _RestorePreviewDialog({required this.preview});
  final BackupPreview preview;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('恢复这份备份？'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '保存于 ${DateFormat('yyyy年M月d日 HH:mm').format(preview.createdAt.toLocal())}',
          ),
          const SizedBox(height: 12),
          const Text('这份备份包含：'),
          Text(
            '${preview.counts['accounts']} 个账户、${preview.counts['transactions']} 笔账单',
          ),
          Text(
            '${preview.counts['schedules']} 项计划、${preview.counts['schedule_skips']} 次已跳过的计划',
          ),
          Text('${preview.counts['merchant_rules']} 条记账推荐规则'),
          const SizedBox(height: 4),
          Text('文件版本：1（可以恢复）', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          const Text('开始恢复前，会先请你保存当前账本的副本。'),
          const SizedBox(height: 12),
          const Text('添加缺少记录：保留当前账本，只加入备份中没有的记录。'),
          const SizedBox(height: 8),
          const Text('替换当前账本：清除当前内容，改用这份备份。'),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, RestoreMode.merge),
        child: const Text('添加缺少记录'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, RestoreMode.replace),
        child: const Text('替换当前账本'),
      ),
    ],
  );
}
