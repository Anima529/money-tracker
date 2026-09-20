import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

const defaultAccountUuid = '00000000-0000-4000-8000-000000000001';

/// 账户只保存初始余额；当前余额由已确认交易实时计算。
@DataClassName('AccountRow')
class Accounts extends Table {
  /// 本地自增主键。
  IntColumn get id => integer().autoIncrement()();

  /// 备份和合并时使用的稳定标识。
  TextColumn get uuid => text().withLength(min: 36, max: 36).unique()();

  /// 用户可见的账户名称。
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// 账户类型，如现金、支付宝或银行卡。
  TextColumn get type => text()();

  /// 建账时的余额，单位为分。
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();

  /// 界面使用的图标键。
  TextColumn get icon => text().withLength(min: 1, max: 64)();

  /// ARGB 颜色整数。
  IntColumn get color => integer()();

  /// 是否参与“安心可花”计算。
  BoolColumn get isSpendable => boolean().withDefault(const Constant(true))();

  /// 归档账户保留历史数据但默认隐藏。
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// 账户列表中的显示顺序。
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 首次创建时间。
  DateTimeColumn get createdAt => dateTime()();

  /// 最近修改时间。
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<String> get customConstraints => const [
    "CHECK (type IN ('cash', 'alipay', 'wechat', 'bank', 'other'))",
    'CHECK (initial_balance BETWEEN -999999999999 AND 999999999999)',
    'CHECK (sort_order >= 0)',
  ];
}

@TableIndex.sql(
  'CREATE INDEX schedules_next_date_idx ON schedules (is_enabled, next_date)',
)
/// 周期计划只保存规则，未来实例在查询时展开。
@DataClassName('ScheduleRow')
class Schedules extends Table {
  /// 本地自增主键。
  IntColumn get id => integer().autoIncrement()();

  /// 备份和合并时使用的稳定标识。
  TextColumn get uuid => text().withLength(min: 36, max: 36).unique()();

  /// 用户可见的计划标题。
  TextColumn get title => text().withLength(min: 1, max: 100)();

  /// 计划类型：收入、支出或转账。
  TextColumn get type => text()();

  /// 每次发生的金额，单位为分。
  IntColumn get amount => integer()();

  /// 稳定的分类 ID。
  TextColumn get category => text().withLength(min: 1, max: 64)();

  /// 收款、付款或转出账户。
  IntColumn get accountId =>
      integer().references(Accounts, #id, onDelete: KeyAction.restrict)();

  /// 转账目标账户；普通收支为空。
  @ReferenceName('destinationSchedules')
  IntColumn get transferAccountId => integer().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.restrict,
  )();

  /// 重复频率。
  TextColumn get frequency => text()();

  /// 每隔多少个频率单位执行一次。
  IntColumn get interval => integer().withDefault(const Constant(1))();

  /// 计划首次生效日期。
  DateTimeColumn get startDate => dateTime()();

  /// 下一次待处理日期。
  DateTimeColumn get nextDate => dateTime()();

  /// 可选的计划结束日期。
  DateTimeColumn get endDate => dateTime().nullable()();

  /// 是否属于安心可花中的必要支出。
  BoolColumn get isEssential => boolean().withDefault(const Constant(false))();

  /// 停用后不再参与未来预测。
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  /// 首次创建时间。
  DateTimeColumn get createdAt => dateTime()();

  /// 最近修改时间。
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<String> get customConstraints => const [
    "CHECK (type IN ('income', 'expense', 'transfer'))",
    'CHECK (amount BETWEEN 1 AND 999999999999)',
    "CHECK (frequency IN ('weekly', 'monthly', 'yearly', 'custom'))",
    'CHECK (interval >= 1)',
    'CHECK ((type = \'transfer\' AND transfer_account_id IS NOT NULL AND transfer_account_id <> account_id) OR (type <> \'transfer\' AND transfer_account_id IS NULL))',
    'CHECK (next_date >= start_date)',
    'CHECK (end_date IS NULL OR end_date >= start_date)',
  ];
}

@TableIndex.sql(
  'CREATE INDEX transactions_date_idx ON transactions (transaction_date)',
)
@TableIndex.sql(
  'CREATE INDEX transactions_status_type_date_idx ON transactions (status, type, transaction_date)',
)
@TableIndex.sql(
  'CREATE INDEX transactions_account_status_idx ON transactions (account_id, status)',
)
@TableIndex.sql(
  'CREATE UNIQUE INDEX transactions_schedule_date_idx ON transactions (schedule_id, scheduled_for) WHERE schedule_id IS NOT NULL AND scheduled_for IS NOT NULL',
)
/// 正式、计划和候选交易共用此表，由 status 决定是否参与计算。
@DataClassName('TransactionRow')
class Transactions extends Table {
  /// 本地自增主键。
  IntColumn get id => integer().autoIncrement()();

  /// 备份、导入和合并时使用的稳定标识。
  TextColumn get uuid => text().withLength(min: 36, max: 36).unique()();

  /// 交易类型：收入、支出或转账。
  TextColumn get type => text()();

  /// 正数金额，单位为分。
  IntColumn get amount => integer()();

  /// 稳定的分类 ID；转账固定为 transfer。
  TextColumn get category => text().withLength(min: 1, max: 64)();

  /// 收款、付款或转出账户。
  IntColumn get accountId =>
      integer().references(Accounts, #id, onDelete: KeyAction.restrict)();

  /// 转账目标账户；普通收支为空。
  @ReferenceName('destinationTransactions')
  IntColumn get transferAccountId => integer().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.restrict,
  )();

  /// 是否已确认、待发生或待确认。
  TextColumn get status => text()();

  /// 交易的录入来源。
  TextColumn get source => text()();

  /// 可选的商户名称。
  TextColumn get merchant => text().withLength(max: 200).nullable()();

  /// 自动识别置信度，范围为 0 到 100。
  IntColumn get confidence => integer().nullable()();

  /// 生成该交易的周期计划。
  IntColumn get scheduleId => integer().nullable().references(
    Schedules,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// 周期计划原定发生日期。
  DateTimeColumn get scheduledFor => dateTime().nullable()();

  /// 通知或导入记录的去重指纹。
  TextColumn get sourceFingerprint =>
      text().withLength(max: 256).nullable().unique()();

  /// 用户填写的备注。
  TextColumn get note =>
      text().withLength(max: 1000).withDefault(const Constant(''))();

  /// 交易归属日期，按本地自然日保存。
  DateTimeColumn get transactionDate => dateTime()();

  /// 正式确认时间；非 confirmed 状态为空。
  DateTimeColumn get confirmedAt => dateTime().nullable()();

  /// 移入回收站的时间；为空表示账单仍在正常使用。
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// 首次创建时间。
  DateTimeColumn get createdAt => dateTime()();

  /// 最近修改时间。
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<String> get customConstraints => const [
    "CHECK (type IN ('income', 'expense', 'transfer'))",
    'CHECK (amount BETWEEN 1 AND 999999999999)',
    "CHECK (status IN ('confirmed', 'planned', 'suggested'))",
    "CHECK (source IN ('manual', 'notification', 'import', 'schedule'))",
    'CHECK (confidence IS NULL OR confidence BETWEEN 0 AND 100)',
    'CHECK ((type = \'transfer\' AND transfer_account_id IS NOT NULL AND transfer_account_id <> account_id) OR (type <> \'transfer\' AND transfer_account_id IS NULL))',
    "CHECK ((status = 'confirmed' AND confirmed_at IS NOT NULL) OR (status <> 'confirmed' AND confirmed_at IS NULL))",
  ];
}

@TableIndex.sql(
  'CREATE UNIQUE INDEX schedule_skips_schedule_date_idx ON schedule_skips (schedule_id, scheduled_for)',
)
/// 被用户明确跳过的计划实例，不参与预测且不生成交易。
@DataClassName('ScheduleSkipRow')
class ScheduleSkips extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 被跳过的周期计划 ID。
  IntColumn get scheduleId =>
      integer().references(Schedules, #id, onDelete: KeyAction.cascade)();

  /// 原计划发生日期，按本地自然日保存。
  DateTimeColumn get scheduledFor => dateTime()();

  /// 用户执行跳过操作的时间。
  DateTimeColumn get createdAt => dateTime()();
}

@TableIndex.sql(
  'CREATE INDEX merchant_rules_use_idx ON merchant_rules (use_count DESC, last_used_at DESC)',
)
/// 本地商户匹配规则；不会上传到任何服务器。
@DataClassName('MerchantRuleRow')
class MerchantRules extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 用于包含匹配的商户文本。
  TextColumn get pattern => text().withLength(min: 1, max: 200).unique()();

  /// 推荐的稳定分类 ID。
  TextColumn get category => text().withLength(min: 1, max: 64)();

  /// 可选的推荐账户 ID。
  IntColumn get accountId => integer().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// 规范化后的商户展示名。
  TextColumn get merchant => text().withLength(max: 200).nullable()();

  /// 规则被确认使用的次数。
  IntColumn get useCount => integer().withDefault(const Constant(0))();

  /// 最近一次被确认使用的时间。
  DateTimeColumn get lastUsedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<String> get customConstraints => const ['CHECK (use_count >= 0)'];
}

@DriftDatabase(
  tables: [Accounts, Schedules, Transactions, ScheduleSkips, MerchantRules],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _insertDefaultAccount();
    },
    onUpgrade: (migrator, from, to) async {
      if (from == 1) await _migrateFromVersion1(migrator);
      if (from < 3) {
        await migrator.createTable(scheduleSkips);
        await migrator.createTable(merchantRules);
      }
      // v1 会在上方直接按最新结构重建交易表，无需重复加列。
      if (from >= 2 && from < 4) {
        await migrator.addColumn(transactions, transactions.deletedAt);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _insertDefaultAccount() => customStatement(
    '''
      INSERT INTO accounts (
        id, uuid, name, type, initial_balance, icon, color,
        is_spendable, is_archived, sort_order, created_at, updated_at
      ) VALUES (1, ?, '默认账户', 'other', 0, 'wallet', 4285164138, 1, 0, 0,
        CAST(strftime('%s', 'now') AS INTEGER), CAST(strftime('%s', 'now') AS INTEGER))
    ''',
    [defaultAccountUuid],
  );

  Future<void> _migrateFromVersion1(Migrator migrator) async {
    // 重建表而不是逐列追加，确保升级库和新建库拥有完全相同的约束。
    await customStatement('ALTER TABLE transactions RENAME TO transactions_v1');
    await customStatement('DROP INDEX IF EXISTS transactions_date_idx');
    await customStatement('DROP INDEX IF EXISTS transactions_type_date_idx');

    await migrator.createTable(accounts);
    await migrator.createTable(schedules);
    await _insertDefaultAccount();
    await migrator.createTable(transactions);

    // 旧交易归入默认账户，并补齐阶段 1 新增的必填字段。
    await customStatement('''
      INSERT INTO transactions (
        id, uuid, type, amount, category, account_id, transfer_account_id,
        status, source, merchant, confidence, schedule_id, scheduled_for,
        source_fingerprint, note, transaction_date, confirmed_at,
        created_at, updated_at
      )
      SELECT
        id,
        printf('00000000-0000-4000-8000-%012x', id),
        type, amount, category, 1, NULL,
        'confirmed', 'manual', NULL, NULL, NULL, NULL,
        NULL, note, transaction_date, created_at,
        created_at, updated_at
      FROM transactions_v1
    ''');
    await customStatement('DROP TABLE transactions_v1');
  }
}

// 数据库文件位于应用私有目录；SQLite 操作交给后台 isolate。
LazyDatabase _openConnection() => LazyDatabase(() async {
  final directory = await getApplicationSupportDirectory();
  final file = File(p.join(directory.path, 'money_tracker.sqlite'));
  return NativeDatabase.createInBackground(file);
});
