import 'transaction.dart';

abstract interface class TransactionRepository {
  Future<int> add(TransactionDraft draft);

  /// 撤销删除时恢复原有稳定标识和审计时间。
  Future<int> restore(Transaction transaction);
  Future<bool> update(int id, TransactionDraft draft);
  Future<bool> delete(int id);
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
}
