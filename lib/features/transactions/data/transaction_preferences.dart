import 'package:shared_preferences/shared_preferences.dart';

import '../domain/transaction.dart';

/// 保存最近选择，减少下一次手动记账需要重复操作的字段。
class TransactionPreferences {
  const TransactionPreferences(this.preferences);

  final SharedPreferences preferences;

  static const _accountKey = 'transaction_recent_account_id';
  static const _expenseCategoryKey = 'transaction_recent_expense_category';
  static const _incomeCategoryKey = 'transaction_recent_income_category';

  int? get recentAccountId => preferences.getInt(_accountKey);

  String? recentCategory(TransactionType type) => preferences.getString(
    type == TransactionType.income ? _incomeCategoryKey : _expenseCategoryKey,
  );

  Future<void> remember({
    required int accountId,
    required TransactionType type,
    required String category,
  }) async {
    final results = await Future.wait([
      preferences.setInt(_accountKey, accountId),
      if (type != TransactionType.transfer)
        preferences.setString(
          type == TransactionType.income
              ? _incomeCategoryKey
              : _expenseCategoryKey,
          category,
        ),
    ]);
    if (results.any((saved) => !saved)) {
      throw StateError('Unable to save recent transaction selections');
    }
  }
}
