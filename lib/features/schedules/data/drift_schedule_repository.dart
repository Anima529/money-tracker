import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../../../core/utils/app_dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/uuid.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/domain/transaction_category.dart';
import '../domain/schedule.dart';
import '../domain/schedule_repository.dart';
import 'schedule_dao.dart';
import 'schedule_skip_dao.dart';
import '../domain/schedule_instance.dart';

/// 校验并持久化周期规则；实例展开留给预测阶段处理。
class DriftScheduleRepository implements ScheduleRepository {
  DriftScheduleRepository(
    this.dao,
    this.skipDao, {
    DateTime Function()? clock,
    String Function()? uuid,
  }) : _clock = clock ?? DateTime.now,
       _uuid = uuid ?? Uuid.v4;

  /// 周期计划表的数据访问对象。
  final ScheduleDao dao;
  final ScheduleSkipDao skipDao;

  /// 可注入时钟，便于测试时间字段。
  final DateTime Function() _clock;

  /// 可注入 UUID 生成器，便于测试稳定标识。
  final String Function() _uuid;

  SchedulesCompanion _values(ScheduleDraft draft, {required bool creating}) {
    final title = draft.title.trim();
    if (title.isEmpty || title.length > 100) {
      throw ArgumentError.value(draft.title, 'title');
    }
    if (draft.amount <= 0 || draft.amount > Money.maxCents) {
      throw ArgumentError.value(draft.amount, 'amount');
    }
    if (draft.accountId <= 0) {
      throw ArgumentError.value(draft.accountId, 'accountId');
    }
    _validateTypeAndCategory(
      type: draft.type,
      category: draft.category,
      accountId: draft.accountId,
      transferAccountId: draft.transferAccountId,
    );
    if (draft.interval < 1) {
      throw ArgumentError.value(draft.interval, 'interval');
    }
    final startDate = AppDates.dayStart(draft.startDate);
    final nextDate = AppDates.dayStart(draft.nextDate);
    final endDate = draft.endDate == null
        ? null
        : AppDates.dayStart(draft.endDate!);
    if (nextDate.isBefore(startDate)) {
      throw ArgumentError('nextDate 不能早于 startDate');
    }
    if (endDate != null && endDate.isBefore(startDate)) {
      throw ArgumentError('endDate 不能早于 startDate');
    }
    final now = _clock();
    return SchedulesCompanion(
      uuid: creating ? Value(_uuid()) : const Value.absent(),
      title: Value(title),
      type: Value(draft.type.name),
      amount: Value(draft.amount),
      category: Value(draft.category),
      accountId: Value(draft.accountId),
      transferAccountId: Value(draft.transferAccountId),
      frequency: Value(draft.frequency.name),
      interval: Value(draft.interval),
      startDate: Value(startDate),
      nextDate: Value(nextDate),
      endDate: Value(endDate),
      isEssential: Value(draft.isEssential),
      isEnabled: Value(draft.isEnabled),
      createdAt: creating ? Value(now) : const Value.absent(),
      updatedAt: Value(now),
    );
  }

  @override
  Future<int> add(ScheduleDraft draft) =>
      dao.insert(_values(draft, creating: true));

  @override
  Future<bool> update(int id, ScheduleDraft draft) async =>
      await dao.update(id, _values(draft, creating: false)) > 0;

  @override
  Future<bool> delete(int id) async => await dao.delete(id) > 0;

  @override
  Future<List<Schedule>> getAll({bool enabledOnly = false}) async =>
      (await dao.get(enabledOnly: enabledOnly))
          .map(_map)
          .toList(growable: false);

  @override
  Stream<List<Schedule>> watchAll({bool enabledOnly = false}) => dao
      .watch(enabledOnly: enabledOnly)
      .map((rows) => rows.map(_map).toList(growable: false));

  @override
  Future<void> skip(int scheduleId, DateTime scheduledFor) async {
    final day = AppDates.dayStart(scheduledFor);
    await skipDao.insert(
      ScheduleSkipsCompanion.insert(
        scheduleId: scheduleId,
        scheduledFor: day,
        createdAt: _clock(),
      ),
    );
  }

  @override
  Future<bool> unskip(int scheduleId, DateTime scheduledFor) async =>
      await skipDao.delete(scheduleId, AppDates.dayStart(scheduledFor)) > 0;

  @override
  Future<List<ScheduleSkip>> getSkips() async =>
      (await skipDao.getAll()).map(_mapSkip).toList(growable: false);

  @override
  Stream<List<ScheduleSkip>> watchSkips() => skipDao.watchAll().map(
    (rows) => rows.map(_mapSkip).toList(growable: false),
  );

  static Schedule _map(ScheduleRow row) => Schedule(
    id: row.id,
    uuid: row.uuid,
    title: row.title,
    type: TransactionType.values.byName(row.type),
    amount: row.amount,
    category: row.category,
    accountId: row.accountId,
    transferAccountId: row.transferAccountId,
    frequency: ScheduleFrequency.values.byName(row.frequency),
    interval: row.interval,
    startDate: row.startDate,
    nextDate: row.nextDate,
    endDate: row.endDate,
    isEssential: row.isEssential,
    isEnabled: row.isEnabled,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  static ScheduleSkip _mapSkip(ScheduleSkipRow row) => ScheduleSkip(
    id: row.id,
    scheduleId: row.scheduleId,
    scheduledFor: row.scheduledFor,
    createdAt: row.createdAt,
  );
}

void _validateTypeAndCategory({
  required TransactionType type,
  required String category,
  required int accountId,
  required int? transferAccountId,
}) {
  // 计划转账沿用交易的双账户约束。
  if (type == TransactionType.transfer) {
    if (category != 'transfer') throw ArgumentError.value(category, 'category');
    if (transferAccountId == null || transferAccountId == accountId) {
      throw ArgumentError.value(transferAccountId, 'transferAccountId');
    }
    return;
  }
  if (transferAccountId != null) {
    throw ArgumentError.value(transferAccountId, 'transferAccountId');
  }
  final known = Categories.find(category);
  if (known == null || known.type != type) {
    throw ArgumentError.value(category, 'category');
  }
}
