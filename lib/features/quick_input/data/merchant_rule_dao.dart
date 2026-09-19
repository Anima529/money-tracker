import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class MerchantRuleDao {
  const MerchantRuleDao(this.database);

  final AppDatabase database;

  SimpleSelectStatement<MerchantRules, MerchantRuleRow> _query() =>
      database.select(database.merchantRules)..orderBy([
        (row) => OrderingTerm.desc(row.useCount),
        (row) => OrderingTerm.desc(row.lastUsedAt),
        (row) => OrderingTerm.asc(row.id),
      ]);

  Future<List<MerchantRuleRow>> getAll() => _query().get();
  Stream<List<MerchantRuleRow>> watchAll() => _query().watch();

  Future<MerchantRuleRow?> find(String pattern) => (database.select(
    database.merchantRules,
  )..where((row) => row.pattern.equals(pattern))).getSingleOrNull();

  Future<int> insert(MerchantRulesCompanion value) =>
      database.into(database.merchantRules).insert(value);

  Future<int> update(int id, MerchantRulesCompanion value) => (database.update(
    database.merchantRules,
  )..where((row) => row.id.equals(id))).write(value);

  Future<int> delete(int id) => (database.delete(
    database.merchantRules,
  )..where((row) => row.id.equals(id))).go();

  Future<int> clear() => database.delete(database.merchantRules).go();
}
