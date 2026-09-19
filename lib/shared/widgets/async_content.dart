import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsyncContent<T> extends StatelessWidget {
  const AsyncContent({
    super.key,
    required this.value,
    required this.builder,
    required this.onRetry,
  });

  /// 当前异步数据状态。
  final AsyncValue<T> value;

  /// 数据加载成功后的内容构建器。
  final Widget Function(T) builder;

  /// 加载失败时的重试回调。
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => value.when(
    data: builder,
    loading: () => const Padding(
      padding: EdgeInsets.all(40),
      child: Center(child: CircularProgressIndicator()),
    ),
    error: (error, stack) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.error_outline),
          const SizedBox(height: 12),
          const Text('暂时无法读取本地账单，请重试。'),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    ),
  );
}
