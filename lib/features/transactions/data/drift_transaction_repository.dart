import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../../../core/utils/app_dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/uuid.dart';
import '../domain/transaction.dart';
import '../domain/transaction_category.dart';
import '../domain/transaction_repository.dart';
import 'transaction_dao.dart';

/// 集中处理交易业务校验，避免页面和 DAO 各自实现一套规则。
class DriftTransactionRepository implements TransactionRepository {
  DriftTransactionRepository(
    this.dao, {
    DateTime Function()? clock,
    String Function()? uuid,
  }) : _clock = clock ?? DateTime.now,
       _uuid = uuid ?? Uuid.v4;

  /// 交易表的数据访问对象。
  final TransactionDao dao;

  /// 可注入时钟，便于测试时间字段。
  final DateTime Function() _clock;

  /// 可注入 UUID 生成器，便于测试稳定标识。
  final String Function() _uuid;

  // 创建时间只在新增时写入；修改账单仅刷新 updatedAt。
  TransactionsCompanion _values(
    TransactionDraft draft, {
    required bool creating,
  }) {
    if (draft.amount <= 0 || draft.amount > Money.maxCents) {
      throw ArgumentError.value(draft.amount, 'amount', '金额必须为支持范围内的正整数分');
    }
    if (draft.accountId <= 0) {
      throw ArgumentError.value(draft.accountId, 'accountId');
    }
    // 转账必须有两个不同账户；普通收支只能有一个账户。
    if (draft.type == TransactionType.transfer) {
      if (draft.category != 'transfer') {
        throw ArgumentError.value(
          draft.category,
          'category',
          '转账分类必须为 transfer',
        );
      }
      if (draft.transferAccountId == null ||
          draft.transferAccountId == draft.accountId) {
        throw ArgumentError.value(
          draft.transferAccountId,
          'transferAccountId',
          '转账必须选择另一个账户',
        );
      }
    } else {
      final category = Categories.find(draft.category);
      if (category == null || category.type != draft.type) {
        throw ArgumentError.value(draft.category, 'category', '分类与收支类型不匹配');
      }
      if (draft.transferAccountId != null) {
        throw ArgumentError.value(
          draft.transferAccountId,
          'transferAccountId',
          '普通收支不能设置转入账户',
        );
      }
    }
    if (draft.note.length > 1000) throw ArgumentError('备注不能超过 1000 字');
    final merchant = draft.merchant?.trim();
    if (merchant != null && merchant.length > 200) {
      throw ArgumentError('商户不能超过 200 字');
    }
    if (draft.confidence != null &&
        (draft.confidence! < 0 || draft.confidence! > 100)) {
      throw ArgumentError.value(draft.confidence, 'confidence');
    }
    final fingerprint = draft.sourceFingerprint?.trim();
    if (fingerprint != null && fingerprint.length > 256) {
      throw ArgumentError('来源指纹不能超过 256 字');
    }
    final now = _clock();
    // 非 confirmed 状态不能携带确认时间，避免误计入真实账目。
    final confirmedAt = draft.status == TransactionStatus.confirmed
        ? (draft.confirmedAt ?? now)
        : null;
    return TransactionsCompanion(
      uuid: creating ? Value(_uuid()) : const Value.absent(),
      type: Value(draft.type.name),
      amount: Value(draft.amount),
      category: Value(draft.category),
      accountId: Value(draft.accountId),
      transferAccountId: Value(draft.transferAccountId),
      status: Value(draft.status.name),
      source: Value(draft.source.name),
      merchant: Value(merchant == null || merchant.isEmpty ? null : merchant),
      confidence: Value(draft.confidence),
      scheduleId: Value(draft.scheduleId),
      scheduledFor: Value(
        draft.scheduledFor == null
            ? null
            : AppDates.dayStart(draft.scheduledFor!),
      ),
      sourceFingerprint: Value(
        fingerprint == null || fingerprint.isEmpty ? null : fingerprint,
      ),
      note: Value(draft.note.trim()),
      transactionDate: Value(AppDates.dayStart(draft.transactionDate)),
      confirmedAt: Value(confirmedAt),
      createdAt: creating ? Value(now) : const Value.absent(),
      updatedAt: Value(now),
    );
  }

  @override
  Future<int> add(TransactionDraft draft) async =>
      dao.insert(_values(draft, creating: true));
  @override
  Future<int> restore(Transaction transaction) {
    // 先复用草稿校验，再覆盖由恢复记录保留的标识和审计字段。
    final validated = _values(transaction.toDraft(), creating: true);
    return dao.insert(
      validated.copyWith(
        uuid: Value(transaction.uuid),
        confirmedAt: Value(transaction.confirmedAt),
        createdAt: Value(transaction.createdAt),
        updatedAt: Value(transaction.updatedAt),
      ),
    );
  }

  @override
  Future<bool> update(int id, TransactionDraft draft) async =>
      await dao.update(id, _values(draft, creating: false)) > 0;
  @override
  Future<bool> delete(int id) async => await dao.delete(id) > 0;
  @override
  Future<List<Transaction>> getAll({
    TransactionType? type,
    TransactionStatus? status,
    int? accountId,
  }) async => _map(
    await dao.get(type: type?.name, status: status?.name, accountId: accountId),
  );
  @override
  Future<List<Transaction>> getByDate(
    DateTime date, {
    TransactionType? type,
    TransactionStatus? status,
  }) async => _map(
    await dao.get(
      start: AppDates.dayStart(date),
      end: AppDates.nextDay(date),
      type: type?.name,
      status: status?.name,
    ),
  );
  @override
  Future<List<Transaction>> getByMonth(
    DateTime month, {
    TransactionType? type,
    TransactionStatus? status,
  }) async => _map(
    await dao.get(
      start: AppDates.monthStart(month),
      end: AppDates.nextMonth(month),
      type: type?.name,
      status: status?.name,
    ),
  );
  @override
  Stream<List<Transaction>> watchAll({
    TransactionType? type,
    TransactionStatus? status,
    int? accountId,
    int? limit,
  }) => dao
      .watch(
        type: type?.name,
        status: status?.name,
        accountId: accountId,
        limit: limit,
      )
      .map(_map);
  @override
  // 月度历史汇总只读取已确认交易。
  Stream<List<Transaction>> watchMonth(DateTime month) => dao
      .watch(
        start: AppDates.monthStart(month),
        end: AppDates.nextMonth(month),
        status: TransactionStatus.confirmed.name,
      )
      .map(_map);

  static List<Transaction> _map(List<TransactionRow> rows) => rows
      .map(
        (row) => Transaction(
          id: row.id,
          uuid: row.uuid,
          type: TransactionType.values.byName(row.type),
          amount: row.amount,
          category: row.category,
          accountId: row.accountId,
          transferAccountId: row.transferAccountId,
          status: TransactionStatus.values.byName(row.status),
          source: TransactionSource.values.byName(row.source),
          merchant: row.merchant,
          confidence: row.confidence,
          scheduleId: row.scheduleId,
          scheduledFor: row.scheduledFor,
          sourceFingerprint: row.sourceFingerprint,
          note: row.note,
          transactionDate: row.transactionDate,
          confirmedAt: row.confirmedAt,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        ),
      )
      .toList(growable: false);
}

extension TransactionDraftConversion on Transaction {
  /// 编辑、复制和撤销删除共用同一套字段映射，避免遗漏金额语义字段。
  TransactionDraft toDraft({bool asManualCopy = false}) => TransactionDraft(
    type: type,
    amount: amount,
    category: category,
    accountId: accountId,
    transferAccountId: transferAccountId,
    status: asManualCopy ? TransactionStatus.confirmed : status,
    source: asManualCopy ? TransactionSource.manual : source,
    merchant: merchant,
    confidence: asManualCopy ? null : confidence,
    scheduleId: asManualCopy ? null : scheduleId,
    scheduledFor: asManualCopy ? null : scheduledFor,
    sourceFingerprint: asManualCopy ? null : sourceFingerprint,
    confirmedAt: asManualCopy ? null : confirmedAt,
    note: note,
    transactionDate: transactionDate,
  );
}
