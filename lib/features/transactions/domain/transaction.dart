enum TransactionType { income, expense, transfer }

enum TransactionStatus {
  confirmed, // 已发生，参与余额和历史统计。
  planned, // 未来事项，只参与预测。
  suggested, // 待确认候选，不参与任何金额计算。
}

enum TransactionSource { manual, notification, import, schedule }

/// 与 Drift、Flutter 无关的交易模型；金额单位统一为分。
class Transaction {
  const Transaction({
    required this.id,
    required this.uuid,
    required this.type,
    required this.amount,
    required this.category,
    required this.accountId,
    required this.transferAccountId,
    required this.status,
    required this.source,
    required this.merchant,
    required this.confidence,
    required this.scheduleId,
    required this.scheduledFor,
    required this.sourceFingerprint,
    required this.note,
    required this.transactionDate,
    required this.confirmedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 本地数据库主键。
  final int id;

  /// 跨备份保持不变的稳定标识。
  final String uuid;

  /// 收入、支出或转账。
  final TransactionType type;

  /// 正数金额，单位为分。
  final int amount;

  /// 稳定的分类 ID，不保存展示名称。
  final String category;

  /// 收款、付款或转出账户 ID。
  final int accountId;

  /// 转账目标账户 ID；普通收支为空。
  final int? transferAccountId;

  /// 决定交易参与余额、预测还是仅作为候选。
  final TransactionStatus status;

  /// 手动、通知、导入或计划等录入来源。
  final TransactionSource source;

  /// 可选的商户名称。
  final String? merchant;

  /// 自动识别置信度，范围为 0 到 100。
  final int? confidence;

  /// 来源周期计划的本地主键。
  final int? scheduleId;

  /// 周期计划原定发生日期。
  final DateTime? scheduledFor;

  /// 通知或导入记录的去重指纹。
  final String? sourceFingerprint;

  /// 用户填写的备注。
  final String note;

  /// 交易归属的本地自然日。
  final DateTime transactionDate;

  /// 正式确认时间；非 confirmed 状态为空。
  final DateTime? confirmedAt;

  /// 首次创建时间。
  final DateTime createdAt;

  /// 最近修改时间。
  final DateTime updatedAt;
}

/// 新增或修改交易时使用的输入模型。
class TransactionDraft {
  const TransactionDraft({
    required this.type,
    required this.amount,
    required this.category,
    required this.accountId,
    required this.transactionDate,
    this.transferAccountId,
    this.status = TransactionStatus.confirmed,
    this.source = TransactionSource.manual,
    this.merchant,
    this.confidence,
    this.scheduleId,
    this.scheduledFor,
    this.sourceFingerprint,
    this.confirmedAt,
    this.note = '',
  });

  /// 收入、支出或转账。
  final TransactionType type;

  /// 正数金额，单位为分。
  final int amount;

  /// 稳定的分类 ID。
  final String category;

  /// 收款、付款或转出账户 ID。
  final int accountId;

  /// 转账目标账户 ID；普通收支为空。
  final int? transferAccountId;

  /// 新交易默认直接确认为正式账目。
  final TransactionStatus status;

  /// 新交易默认来自手动录入。
  final TransactionSource source;

  /// 可选的商户名称。
  final String? merchant;

  /// 自动识别置信度，范围为 0 到 100。
  final int? confidence;

  /// 来源周期计划的本地主键。
  final int? scheduleId;

  /// 周期计划原定发生日期。
  final DateTime? scheduledFor;

  /// 通知或导入记录的去重指纹。
  final String? sourceFingerprint;

  /// 可选的显式确认时间。
  final DateTime? confirmedAt;

  /// 用户填写的备注。
  final String note;

  /// 交易归属日期。
  final DateTime transactionDate;
}
