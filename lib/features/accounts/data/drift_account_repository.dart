import 'package:drift/drift.dart' show QueryRow, Value;

import '../../../core/database/app_database.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/uuid.dart';
import '../domain/account.dart';
import '../domain/account_repository.dart';
import 'account_dao.dart';

/// 负责账户输入校验，并在 DAO 与领域模型之间转换。
class DriftAccountRepository implements AccountRepository {
  DriftAccountRepository(
    this.dao, {
    DateTime Function()? clock,
    String Function()? uuid,
  }) : _clock = clock ?? DateTime.now,
       _uuid = uuid ?? Uuid.v4;

  /// 账户表的数据访问对象。
  final AccountDao dao;

  /// 可注入时钟，便于测试时间字段。
  final DateTime Function() _clock;

  /// 可注入 UUID 生成器，便于测试稳定标识。
  final String Function() _uuid;

  AccountsCompanion _values(AccountDraft draft, {required bool creating}) {
    final name = draft.name.trim();
    if (name.isEmpty || name.length > 100) {
      throw ArgumentError.value(draft.name, 'name', '账户名称长度必须为 1 到 100');
    }
    if (draft.initialBalance.abs() > Money.maxCents) {
      throw ArgumentError.value(draft.initialBalance, 'initialBalance');
    }
    if (draft.icon.isEmpty || draft.icon.length > 64) {
      throw ArgumentError.value(draft.icon, 'icon');
    }
    if (draft.sortOrder < 0) {
      throw ArgumentError.value(draft.sortOrder, 'sortOrder');
    }
    final now = _clock();
    return AccountsCompanion(
      uuid: creating ? Value(_uuid()) : const Value.absent(),
      name: Value(name),
      type: Value(draft.type.name),
      initialBalance: Value(draft.initialBalance),
      icon: Value(draft.icon),
      color: Value(draft.color),
      isSpendable: Value(draft.isSpendable),
      isArchived: Value(draft.isArchived),
      sortOrder: Value(draft.sortOrder),
      createdAt: creating ? Value(now) : const Value.absent(),
      updatedAt: Value(now),
    );
  }

  @override
  Future<int> add(AccountDraft draft) =>
      dao.insert(_values(draft, creating: true));

  @override
  Future<bool> update(int id, AccountDraft draft) async =>
      await dao.update(id, _values(draft, creating: false)) > 0;

  @override
  Future<bool> delete(int id) async => await dao.delete(id) > 0;

  @override
  Future<List<Account>> getAll({bool includeArchived = false}) async =>
      (await dao.get(includeArchived: includeArchived))
          .map(_map)
          .toList(growable: false);

  @override
  Stream<List<Account>> watchAll({bool includeArchived = false}) => dao
      .watch(includeArchived: includeArchived)
      .map((rows) => rows.map(_map).toList(growable: false));

  @override
  Future<List<AccountBalance>> getBalances({
    bool includeArchived = false,
  }) async =>
      (await dao.getBalances(includeArchived: includeArchived))
          .map(_mapBalance)
          .toList(growable: false);

  @override
  Stream<List<AccountBalance>> watchBalances({bool includeArchived = false}) =>
      dao
          .watchBalances(includeArchived: includeArchived)
          .map((rows) => rows.map(_mapBalance).toList(growable: false));

  static Account _map(AccountRow row) => Account(
    id: row.id,
    uuid: row.uuid,
    name: row.name,
    type: AccountType.values.byName(row.type),
    initialBalance: row.initialBalance,
    icon: row.icon,
    color: row.color,
    isSpendable: row.isSpendable,
    isArchived: row.isArchived,
    sortOrder: row.sortOrder,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  static AccountBalance _mapBalance(QueryRow row) => AccountBalance(
    account: Account(
      id: row.read<int>('id'),
      uuid: row.read<String>('uuid'),
      name: row.read<String>('name'),
      type: AccountType.values.byName(row.read<String>('type')),
      initialBalance: row.read<int>('initial_balance'),
      icon: row.read<String>('icon'),
      color: row.read<int>('color'),
      isSpendable: row.read<bool>('is_spendable'),
      isArchived: row.read<bool>('is_archived'),
      sortOrder: row.read<int>('sort_order'),
      createdAt: row.read<DateTime>('created_at'),
      updatedAt: row.read<DateTime>('updated_at'),
    ),
    currentBalance: row.read<int>('current_balance'),
  );
}
