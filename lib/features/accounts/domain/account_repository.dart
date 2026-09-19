import 'account.dart';

abstract interface class AccountRepository {
  Future<int> add(AccountDraft draft);
  Future<bool> update(int id, AccountDraft draft);
  Future<bool> delete(int id);
  Future<List<Account>> getAll({bool includeArchived = false});
  Stream<List<Account>> watchAll({bool includeArchived = false});
  Future<List<AccountBalance>> getBalances({bool includeArchived = false});
  Stream<List<AccountBalance>> watchBalances({bool includeArchived = false});
}
