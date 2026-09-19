import '../../transactions/domain/transaction.dart';

enum ScheduleFrequency { weekly, monthly, yearly, custom }

/// 周期规则本身；尚未发生的实例不会提前写入交易表。
class Schedule {
  const Schedule({
    required this.id,
    required this.uuid,
    required this.title,
    required this.type,
    required this.amount,
    required this.category,
    required this.accountId,
    required this.transferAccountId,
    required this.frequency,
    required this.interval,
    required this.startDate,
    required this.nextDate,
    required this.endDate,
    required this.isEssential,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 本地数据库主键。
  final int id;

  /// 跨备份保持不变的稳定标识。
  final String uuid;

  /// 用户可见的计划标题。
  final String title;

  /// 计划产生收入、支出还是转账。
  final TransactionType type;

  /// 每次发生的金额，单位为分。
  final int amount;

  /// 稳定的分类 ID。
  final String category;

  /// 收款、付款或转出账户 ID。
  final int accountId;

  /// 转账目标账户 ID；普通收支为空。
  final int? transferAccountId;

  /// 每周、每月、每年或自定义频率。
  final ScheduleFrequency frequency;

  /// 每隔多少个频率单位执行一次。
  final int interval;

  /// 计划首次生效日期。
  final DateTime startDate;

  /// 下一次待处理日期。
  final DateTime nextDate;

  /// 可选的计划结束日期。
  final DateTime? endDate;

  /// 是否属于安心可花中的必要支出。
  final bool isEssential;

  /// 停用后不再参与未来预测。
  final bool isEnabled;

  /// 首次创建时间。
  final DateTime createdAt;

  /// 最近修改时间。
  final DateTime updatedAt;
}

/// 新增或修改周期规则时使用的输入模型。
class ScheduleDraft {
  const ScheduleDraft({
    required this.title,
    required this.type,
    required this.amount,
    required this.category,
    required this.accountId,
    required this.frequency,
    required this.startDate,
    required this.nextDate,
    this.transferAccountId,
    this.interval = 1,
    this.endDate,
    this.isEssential = false,
    this.isEnabled = true,
  });

  /// 用户可见的计划标题。
  final String title;

  /// 计划产生收入、支出还是转账。
  final TransactionType type;

  /// 每次发生的金额，单位为分。
  final int amount;

  /// 稳定的分类 ID。
  final String category;

  /// 收款、付款或转出账户 ID。
  final int accountId;

  /// 转账目标账户 ID；普通收支为空。
  final int? transferAccountId;

  /// 计划的重复频率。
  final ScheduleFrequency frequency;

  /// 每隔多少个频率单位执行一次。
  final int interval;

  /// 计划首次生效日期。
  final DateTime startDate;

  /// 下一次待处理日期。
  final DateTime nextDate;

  /// 可选的计划结束日期。
  final DateTime? endDate;

  /// 是否属于安心可花中的必要支出。
  final bool isEssential;

  /// 是否启用该计划。
  final bool isEnabled;
}
