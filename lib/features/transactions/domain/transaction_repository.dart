import 'transaction.dart';

abstract interface class TransactionRepository {
  Future<int> add(TransactionDraft draft);

  Future<bool> update(int id, TransactionDraft draft);

  /// 将账单移入回收站，不立即移除数据。
  Future<bool> delete(int id);

  /// 将账单从回收站恢复到正常列表。
  Future<bool> restore(int id);

  /// 真正移除回收站中的账单，操作不可撤销。
  Future<bool> permanentlyDelete(int id);
  Future<List<Transaction>> getAll({
    TransactionType? type,
    TransactionStatus? status,
    int? accountId,
  });
  Future<List<Transaction>> getByDate(
    DateTime date, {
    TransactionType? type,
    TransactionStatus? status,
  });
  Future<List<Transaction>> getByMonth(
    DateTime month, {
    TransactionType? type,
    TransactionStatus? status,
  });
  Stream<List<Transaction>> watchAll({
    TransactionType? type,
    TransactionStatus? status,
    int? accountId,
    int? limit,
  });
  Stream<List<Transaction>> watchMonth(DateTime month);

  /// 按最近删除时间倒序观察回收站内容。
  Stream<List<Transaction>> watchTrash();
}
