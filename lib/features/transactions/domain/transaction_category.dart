import 'transaction.dart';

/// 可用于交易选择和展示的分类定义。
class TransactionCategory {
  const TransactionCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.iconKey,
    required this.colorValue,
    this.isCustom = false,
  });

  /// 写入交易表的稳定分类 ID。
  final String id;

  /// 用户可见的分类名称。
  final String name;

  /// 分类适用的交易类型。
  final TransactionType type;

  /// 对应 Material 图标的键。
  final String iconKey;

  /// ARGB 颜色整数。
  final int colorValue;

  /// 是否由用户自行创建。
  final bool isCustom;
}

abstract final class Categories {
  /// 应用内置的收入和支出分类。
  static const all = <TransactionCategory>[
    TransactionCategory(
      id: 'food',
      name: '餐饮',
      type: TransactionType.expense,
      iconKey: 'restaurant',
      colorValue: 0xFF9A7355,
    ),
    TransactionCategory(
      id: 'transport',
      name: '交通',
      type: TransactionType.expense,
      iconKey: 'train',
      colorValue: 0xFF607C96,
    ),
    TransactionCategory(
      id: 'shopping',
      name: '购物',
      type: TransactionType.expense,
      iconKey: 'shopping',
      colorValue: 0xFF93728B,
    ),
    TransactionCategory(
      id: 'entertainment',
      name: '娱乐',
      type: TransactionType.expense,
      iconKey: 'movie',
      colorValue: 0xFF7B789E,
    ),
    TransactionCategory(
      id: 'housing',
      name: '居住',
      type: TransactionType.expense,
      iconKey: 'home',
      colorValue: 0xFF7F8863,
    ),
    TransactionCategory(
      id: 'health',
      name: '医疗',
      type: TransactionType.expense,
      iconKey: 'health',
      colorValue: 0xFFAA7474,
    ),
    TransactionCategory(
      id: 'education',
      name: '教育',
      type: TransactionType.expense,
      iconKey: 'school',
      colorValue: 0xFF688885,
    ),
    TransactionCategory(
      id: 'expense_other',
      name: '其他',
      type: TransactionType.expense,
      iconKey: 'more',
      colorValue: 0xFF7B8187,
    ),
    TransactionCategory(
      id: 'salary',
      name: '工资',
      type: TransactionType.income,
      iconKey: 'work',
      colorValue: 0xFF588478,
    ),
    TransactionCategory(
      id: 'bonus',
      name: '奖金',
      type: TransactionType.income,
      iconKey: 'award',
      colorValue: 0xFF938259,
    ),
    TransactionCategory(
      id: 'part_time',
      name: '兼职',
      type: TransactionType.income,
      iconKey: 'work',
      colorValue: 0xFF607C96,
    ),
    TransactionCategory(
      id: 'investment',
      name: '理财',
      type: TransactionType.income,
      iconKey: 'trend',
      colorValue: 0xFF688885,
    ),
    TransactionCategory(
      id: 'gift',
      name: '红包',
      type: TransactionType.income,
      iconKey: 'gift',
      colorValue: 0xFFAA7474,
    ),
    TransactionCategory(
      id: 'income_other',
      name: '其他',
      type: TransactionType.income,
      iconKey: 'more',
      colorValue: 0xFF7B8187,
    ),
  ];
  static TransactionCategory? find(String id) {
    for (final category in all) {
      if (category.id == id) return category;
    }
    return null;
  }
}
