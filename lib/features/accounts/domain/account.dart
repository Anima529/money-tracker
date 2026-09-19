enum AccountType { cash, alipay, wechat, bank, other }

/// 账户基础信息，不包含可由交易推导出的当前余额。
class Account {
  const Account({
    required this.id,
    required this.uuid,
    required this.name,
    required this.type,
    required this.initialBalance,
    required this.icon,
    required this.color,
    required this.isSpendable,
    required this.isArchived,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 本地数据库主键。
  final int id;

  /// 跨备份保持不变的稳定标识。
  final String uuid;

  /// 用户可见的账户名称。
  final String name;

  /// 现金、支付平台或银行等账户类型。
  final AccountType type;

  /// 建账时的余额，单位为分。
  final int initialBalance;

  /// 界面使用的图标键。
  final String icon;

  /// ARGB 颜色整数。
  final int color;

  /// 是否参与“安心可花”计算。
  final bool isSpendable;

  /// 是否已归档并默认隐藏。
  final bool isArchived;

  /// 账户列表中的显示顺序。
  final int sortOrder;

  /// 首次创建时间。
  final DateTime createdAt;

  /// 最近修改时间。
  final DateTime updatedAt;
}

class AccountDraft {
  const AccountDraft({
    required this.name,
    required this.type,
    this.initialBalance = 0,
    this.icon = 'wallet',
    this.color = 0xff718096,
    this.isSpendable = true,
    this.isArchived = false,
    this.sortOrder = 0,
  });

  /// 用户可见的账户名称。
  final String name;

  /// 账户类型。
  final AccountType type;

  /// 建账时的余额，单位为分。
  final int initialBalance;

  /// 界面使用的图标键。
  final String icon;

  /// ARGB 颜色整数。
  final int color;

  /// 是否参与“安心可花”计算。
  final bool isSpendable;

  /// 是否归档账户。
  final bool isArchived;

  /// 账户列表中的显示顺序。
  final int sortOrder;
}

/// 账户信息和某一查询时刻的派生余额。
class AccountBalance {
  const AccountBalance({required this.account, required this.currentBalance});

  /// 对应的账户基础信息。
  final Account account;

  /// 初始余额加已确认交易后的余额，单位为分。
  final int currentBalance;
}
