import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

/// 账单查询统一使用 [start, end) 日期范围；SQL 只留在数据层。
class TransactionDao {
  const TransactionDao(this.database);

  /// 当前使用的 Drift 数据库。
  final AppDatabase database;
  Future<int> insert(TransactionsCompanion value) =>
      database.into(database.transactions).insert(value);
  Future<int> update(int id, TransactionsCompanion value) => (database.update(
    database.transactions,
  )..where((row) => row.id.equals(id))).write(value);
  Future<int> delete(int id) => (database.delete(
    database.transactions,
  )..where((row) => row.id.equals(id))).go();

  SimpleSelectStatement<Transactions, TransactionRow> _query({
    DateTime? start,
    DateTime? end,
    String? type,
    String? status,
    int? accountId,
    int? limit,
  }) {
    final query = database.select(database.transactions);
    if (start != null) {
      query.where((row) => row.transactionDate.isBiggerOrEqualValue(start));
    }
    if (end != null) {
      query.where((row) => row.transactionDate.isSmallerThanValue(end));
    }
    if (type != null) query.where((row) => row.type.equals(type));
    if (status != null) query.where((row) => row.status.equals(status));
    if (accountId != null) {
      query.where(
        (row) =>
            row.accountId.equals(accountId) |
            row.transferAccountId.equals(accountId),
      );
    }
    // 同一天按自增 ID 倒序，避免列表顺序在刷新时跳动。
    query.orderBy([
      (row) => OrderingTerm.desc(row.transactionDate),
      (row) => OrderingTerm.desc(row.id),
    ]);
    if (limit != null) {
      if (limit < 1) throw ArgumentError.value(limit, 'limit');
      query.limit(limit);
    }
    return query;
  }

  Future<List<TransactionRow>> get({
    DateTime? start,
    DateTime? end,
    String? type,
    String? status,
    int? accountId,
  }) => _query(
    start: start,
    end: end,
    type: type,
    status: status,
    accountId: accountId,
  ).get();
  Stream<List<TransactionRow>> watch({
    DateTime? start,
    DateTime? end,
    String? type,
    String? status,
    int? accountId,
    int? limit,
  }) => _query(
    start: start,
    end: end,
    type: type,
    status: status,
    accountId: accountId,
    limit: limit,
  ).watch();
}
