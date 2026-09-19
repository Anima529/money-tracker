import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/app/app.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/features/settings/providers/theme_provider.dart';
import 'package:money_tracker/features/transactions/providers/transaction_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('saving the safety buffer closes the dialog without errors', (
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
        ],
        child: const MoneyTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithIcon(NavigationDestination, Icons.settings_outlined),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('安全垫'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('¥100.00'), findsOneWidget);
    expect(preferences.getInt('safety_buffer_cents'), 10000);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await database.close();
  });
}
