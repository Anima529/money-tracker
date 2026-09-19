import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/transactions/presentation/transaction_editor_sheet.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  /// go_router 提供的底部导航状态。
  final StatefulNavigationShell shell;

  /// 各导航分支对应的页面标题。
  static const _titles = ['今天', '未来', '时间线', '设置'];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_titles[shell.currentIndex])),
    body: SafeArea(top: false, child: shell),
    floatingActionButton: shell.currentIndex == 1 || shell.currentIndex == 3
        ? null
        : FloatingActionButton.extended(
            onPressed: () => showTransactionEditor(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('记一笔'),
          ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: (index) =>
          shell.goBranch(index, initialLocation: index == shell.currentIndex),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: '今天',
        ),
        NavigationDestination(
          icon: Icon(Icons.timeline_outlined),
          selectedIcon: Icon(Icons.timeline_rounded),
          label: '未来',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long_rounded),
          label: '时间线',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: '设置',
        ),
      ],
    ),
  );
}
