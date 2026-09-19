import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/features/settings/providers/theme_provider.dart';
import 'package:money_tracker/features/transactions/data/drift_transaction_repository.dart';
import 'package:money_tracker/features/transactions/data/transaction_dao.dart';
import 'package:money_tracker/features/transactions/presentation/transaction_editor_sheet.dart';
import 'package:money_tracker/features/transactions/providers/transaction_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('amount keypad saves once during repeated submit', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftTransactionRepository(TransactionDao(database));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesProvider.overrideWithValue(preferences),
          databaseProvider.overrideWithValue(database),
        ],
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showTransactionEditor(context),
                  child: const Text('打开表单'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('+'));
    await tester.tap(find.text('3'));
    await tester.pump();
    expect(find.text('¥15.00'), findsOneWidget);

    await tester.tap(find.text('保存'));
    // 第二次点击发生在首个保存请求已开始、弹层关闭动画尚未结束时。
    await tester.tap(find.text('保存'), warnIfMissed: false);
    await tester.pumpAndSettle();

    final transactions = await repository.getAll();
    expect(transactions, hasLength(1));
    expect(transactions.single.amount, 1500);
    expect(preferences.getInt('transaction_recent_account_id'), 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await database.close();
  });
}
