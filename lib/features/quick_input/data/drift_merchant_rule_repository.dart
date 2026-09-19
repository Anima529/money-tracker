import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../../transactions/domain/transaction_category.dart';
import '../domain/merchant_rule.dart';
import 'merchant_rule_dao.dart';

class DriftMerchantRuleRepository implements MerchantRuleRepository {
  DriftMerchantRuleRepository(this.dao, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final MerchantRuleDao dao;
  final DateTime Function() _clock;

  @override
  Future<List<MerchantRule>> getAll() async =>
      (await dao.getAll()).map(_map).toList(growable: false);

  @override
  Stream<List<MerchantRule>> watchAll() =>
      dao.watchAll().map((rows) => rows.map(_map).toList(growable: false));

  @override
  Future<void> learn({
    required String pattern,
    required String category,
    int? accountId,
    String? merchant,
  }) async {
    final normalized = pattern.trim().toLowerCase();
    final merchantValue = merchant?.trim();
    if (normalized.isEmpty || normalized.length > 200) {
      throw ArgumentError.value(pattern, 'pattern');
    }
    if (Categories.find(category) == null) {
      throw ArgumentError.value(category, 'category');
    }
    final existing = await dao.find(normalized);
    final now = _clock();
    if (existing == null) {
      await dao.insert(
        MerchantRulesCompanion.insert(
          pattern: normalized,
          category: category,
          accountId: Value(accountId),
          merchant: Value(
            merchantValue == null || merchantValue.isEmpty
                ? null
                : merchantValue,
          ),
          useCount: const Value(1),
          lastUsedAt: Value(now),
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      await dao.update(
        existing.id,
        MerchantRulesCompanion(
          category: Value(category),
          accountId: Value(accountId),
          merchant: Value(
            merchantValue == null || merchantValue.isEmpty
                ? null
                : merchantValue,
          ),
          useCount: Value(existing.useCount + 1),
          lastUsedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }
  }

  @override
  Future<bool> delete(int id) async => await dao.delete(id) > 0;

  @override
  Future<void> clear() async => dao.clear();

  static MerchantRule _map(MerchantRuleRow row) => MerchantRule(
    id: row.id,
    pattern: row.pattern,
    category: row.category,
    accountId: row.accountId,
    merchant: row.merchant,
    useCount: row.useCount,
    lastUsedAt: row.lastUsedAt,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}
