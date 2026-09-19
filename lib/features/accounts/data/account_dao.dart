import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class AccountDao {
  const AccountDao(this.database);

  /// 当前使用的 Drift 数据库。
  final AppDatabase database;

  Future<int> insert(AccountsCompanion value) =>
      database.into(database.accounts).insert(value);

  Future<int> update(int id, AccountsCompanion value) => (database.update(
    database.accounts,
  )..where((row) => row.id.equals(id))).write(value);

  Future<int> delete(int id) => (database.delete(
    database.accounts,
  )..where((row) => row.id.equals(id))).go();

  SimpleSelectStatement<Accounts, AccountRow> _query(bool includeArchived) {
    final query = database.select(database.accounts);
    if (!includeArchived) query.where((row) => row.isArchived.equals(false));
    query.orderBy([
      (row) => OrderingTerm.asc(row.sortOrder),
      (row) => OrderingTerm.asc(row.id),
    ]);
    return query;
  }

  Future<List<AccountRow>> get({bool includeArchived = false}) =>
      _query(includeArchived).get();

  Stream<List<AccountRow>> watch({bool includeArchived = false}) =>
      _query(includeArchived).watch();

  // 只计算 confirmed；转账一减一加，因此不会改变账户总资产。
  Selectable<QueryRow> _balanceQuery({required bool includeArchived}) {
    final archivedClause = includeArchived ? '' : 'WHERE a.is_archived = 0';
    return database.customSelect(
      '''
        SELECT a.*,
          a.initial_balance + COALESCE(SUM(
            CASE
              WHEN t.status <> 'confirmed' THEN 0
              WHEN t.type = 'income' AND t.account_id = a.id THEN t.amount
              WHEN t.type = 'expense' AND t.account_id = a.id THEN -t.amount
              WHEN t.type = 'transfer' AND t.account_id = a.id THEN -t.amount
              WHEN t.type = 'transfer' AND t.transfer_account_id = a.id THEN t.amount
              ELSE 0
            END
          ), 0) AS current_balance
        FROM accounts a
        LEFT JOIN transactions t
          ON t.account_id = a.id OR t.transfer_account_id = a.id
        $archivedClause
        GROUP BY a.id
        ORDER BY a.sort_order, a.id
      ''',
      readsFrom: {database.accounts, database.transactions},
    );
  }

  Future<List<QueryRow>> getBalances({bool includeArchived = false}) =>
      _balanceQuery(includeArchived: includeArchived).get();

  Stream<List<QueryRow>> watchBalances({bool includeArchived = false}) =>
      _balanceQuery(includeArchived: includeArchived).watch();
}
