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
  )..where((row) => row.id.equals(id) & row.deletedAt.isNull())).write(value);
  Future<int> moveToTrash(int id, DateTime deletedAt) =>
      (database.update(database.transactions)
            ..where((row) => row.id.equals(id) & row.deletedAt.isNull()))
          .write(TransactionsCompanion(deletedAt: Value(deletedAt)));
  Future<int> restore(int id) =>
      (database.update(database.transactions)
            ..where((row) => row.id.equals(id) & row.deletedAt.isNotNull()))
          .write(const TransactionsCompanion(deletedAt: Value(null)));
  Future<int> permanentlyDelete(int id) => (database.delete(
    database.transactions,
  )..where((row) => row.id.equals(id) & row.deletedAt.isNotNull())).go();

  SimpleSelectStatement<Transactions, TransactionRow> _query({
    DateTime? start,
    DateTime? end,
    String? type,
    String? status,
    int? accountId,
    int? limit,
    bool trashOnly = false,
  }) {
    final query = database.select(database.transactions);
    query.where(
      (row) => trashOnly ? row.deletedAt.isNotNull() : row.deletedAt.isNull(),
    );
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
    query.orderBy(
      trashOnly
          ? [
              (row) => OrderingTerm.desc(row.deletedAt),
              (row) => OrderingTerm.desc(row.id),
            ]
          : [
              (row) => OrderingTerm.desc(row.transactionDate),
              (row) => OrderingTerm.desc(row.id),
            ],
    );
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
    bool trashOnly = false,
  }) => _query(
    start: start,
    end: end,
    type: type,
    status: status,
    accountId: accountId,
    trashOnly: trashOnly,
  ).get();
  Stream<List<TransactionRow>> watch({
    DateTime? start,
    DateTime? end,
    String? type,
    String? status,
    int? accountId,
    int? limit,
    bool trashOnly = false,
  }) => _query(
    start: start,
    end: end,
    type: type,
    status: status,
    accountId: accountId,
    limit: limit,
    trashOnly: trashOnly,
  ).watch();
}
