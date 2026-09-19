import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/features/home/presentation/summary_card.dart';
import 'package:money_tracker/features/home/providers/home_providers.dart';
import 'package:money_tracker/features/transactions/presentation/transaction_tile.dart';
import 'package:money_tracker/features/transactions/domain/transaction.dart';
import 'package:money_tracker/app/theme/app_theme.dart';

void main() {
  testWidgets(
    'large amounts and long notes fit a narrow screen in both themes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SummaryCard(
                      summary: MonthlySummary(
                        income: 999999999999,
                        expense: 1000000000000,
                      ),
                    ),
                    TransactionTile(
                      transaction: Transaction(
                        id: 1,
                        uuid: '10000000-0000-4000-8000-000000000001',
                        type: TransactionType.expense,
                        amount: 999999999999,
                        category: 'food',
                        accountId: 1,
                        transferAccountId: null,
                        status: TransactionStatus.confirmed,
                        source: TransactionSource.manual,
                        merchant: null,
                        confidence: null,
                        scheduleId: null,
                        scheduledFor: null,
                        sourceFingerprint: null,
                        note: '很长的备注' * 50,
                        transactionDate: DateTime(2026, 9, 17),
                        confirmedAt: DateTime(2026, 9, 17),
                        createdAt: DateTime(2026, 9, 17),
                        updatedAt: DateTime(2026, 9, 17),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('−¥0.01'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
