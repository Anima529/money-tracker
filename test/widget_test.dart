import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_tracker/app/app.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/features/settings/providers/theme_provider.dart';
import 'package:money_tracker/features/transactions/providers/transaction_providers.dart';
import 'package:money_tracker/features/transactions/domain/transaction.dart';

void main() {
  testWidgets('empty dashboard, four destinations, theme and add form', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesProvider.overrideWithValue(preferences),
          databaseProvider.overrideWithValue(database),
          transactionsProvider.overrideWith(
            (ref) => Stream.value(<Transaction>[]),
          ),
          recentTransactionsProvider.overrideWith(
            (ref) => Stream.value(<Transaction>[]),
          ),
          monthlyTransactionsProvider.overrideWith(
            (ref, month) => Stream.value(<Transaction>[]),
          ),
        ],
        child: const MoneyTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('本月结余'), findsOneWidget);
    expect(find.text('¥0.00'), findsNWidgets(4));
    expect(find.text('安心可花'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    await tester.tap(find.text('未来'));
    await tester.pumpAndSettle();
    expect(find.text('接下来 30 天'), findsOneWidget);
    await tester.tap(
      find.widgetWithIcon(NavigationDestination, Icons.receipt_long_outlined),
    );
    await tester.pumpAndSettle();
    expect(find.text('还没有已确认账单'), findsOneWidget);
    await tester.tap(find.text('记一笔'));
    await tester.pumpAndSettle();
    expect(find.text('支出'), findsOneWidget);
    expect(find.text('收入'), findsOneWidget);
    expect(find.text('转账'), findsOneWidget);
    expect(find.byTooltip('关闭'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithIcon(NavigationDestination, Icons.settings_outlined),
    );
    await tester.pumpAndSettle();
    expect(find.text('数据管理'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('回收站'), 200);
    await tester.drag(find.byType(ListView).last, const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.tap(find.text('回收站'));
    await tester.pumpAndSettle();
    expect(find.text('回收站是空的'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('深色'), -200);
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(preferences.getString('theme_mode'), 'dark');
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await database.close();
  });
}
