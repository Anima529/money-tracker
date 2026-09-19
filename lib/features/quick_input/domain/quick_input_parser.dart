import '../../../core/utils/app_dates.dart';
import '../../../core/utils/money.dart';
import '../../accounts/domain/account.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/domain/transaction_category.dart';
import 'merchant_rule.dart';

class QuickInputResult {
  const QuickInputResult({
    required this.originalText,
    required this.amount,
    required this.type,
    required this.category,
    required this.accountId,
    required this.date,
    required this.status,
    required this.merchant,
    required this.matchedRuleId,
    required this.explanations,
  });

  final String originalText;
  final int? amount;
  final TransactionType type;
  final String category;
  final int? accountId;
  final DateTime date;
  final TransactionStatus status;
  final String? merchant;
  final int? matchedRuleId;
  final List<String> explanations;

  bool get hasAmount => amount != null && amount! > 0;
}

/// 完全本地、确定性的中文快速输入解析器。
class QuickInputParser {
  const QuickInputParser();

  static const _incomeWords = ['收入', '工资', '薪资', '奖金', '兼职', '报销', '红包'];
  static const _categoryWords = <String, List<String>>{
    'food': ['餐饮', '吃饭', '午饭', '晚饭', '早餐', '咖啡', '奶茶', '外卖'],
    'transport': ['交通', '打车', '地铁', '公交', '高铁', '火车', '加油'],
    'shopping': ['购物', '淘宝', '京东', '买了'],
    'entertainment': ['娱乐', '电影', '游戏', '演出'],
    'housing': ['房租', '房贷', '水电', '物业'],
    'health': ['医疗', '医院', '看病', '药'],
    'education': ['教育', '课程', '学费', '书'],
    'salary': ['工资', '薪资'],
    'bonus': ['奖金', '年终奖'],
    'part_time': ['兼职', '稿费'],
    'investment': ['理财', '利息', '分红'],
    'gift': ['红包', '礼金'],
  };

  QuickInputResult parse(
    String input, {
    required DateTime now,
    required List<Account> accounts,
    required List<MerchantRule> rules,
  }) {
    final text = input.trim();
    final explanations = <String>[];
    final type = _incomeWords.any(text.contains)
        ? TransactionType.income
        : TransactionType.expense;
    explanations.add(type == TransactionType.income ? '识别为收入' : '识别为支出');

    final amountMatch = _amountMatches(text).lastOrNull;
    int? amount;
    if (amountMatch != null) {
      try {
        final parsed = Money.parseCents(amountMatch.group(1)!);
        if (parsed > 0) {
          amount = parsed;
          explanations.add('金额 ${Money.format(parsed)}');
        }
      } on FormatException {
        amount = null;
      }
    }

    final date = _parseDate(text, AppDates.dayStart(now));
    final status = date.isAfter(AppDates.dayStart(now))
        ? TransactionStatus.planned
        : TransactionStatus.confirmed;
    if (!AppDates.dayStart(date).isAtSameMomentAs(AppDates.dayStart(now))) {
      explanations.add(
        '${status == TransactionStatus.planned ? '计划日期' : '交易日期'} ${AppDates.dayLabel(date)}',
      );
    }

    final account = _matchAccount(text, accounts);
    if (account != null) explanations.add('账户 ${account.name}');

    var category = _matchCategory(text, type);
    var merchant = _extractMerchant(
      text,
      amountText: amountMatch?.group(0),
      accounts: accounts,
    );
    MerchantRule? matchedRule;
    for (final rule in rules) {
      if (text.toLowerCase().contains(rule.pattern.toLowerCase()) ||
          (merchant != null &&
              merchant.toLowerCase().contains(rule.pattern.toLowerCase()))) {
        matchedRule = rule;
        category = rule.category;
        merchant = rule.merchant ?? merchant;
        explanations.add(
          '商户规则推荐 ${Categories.find(category)?.name ?? category}',
        );
        break;
      }
    }
    category ??= type == TransactionType.income
        ? 'income_other'
        : 'expense_other';
    explanations.add('分类 ${Categories.find(category)?.name ?? category}');

    return QuickInputResult(
      originalText: text,
      amount: amount,
      type: type,
      category: category,
      accountId: matchedRule?.accountId ?? account?.id,
      date: date,
      status: status,
      merchant: merchant,
      matchedRuleId: matchedRule?.id,
      explanations: explanations,
    );
  }

  static Iterable<RegExpMatch> _amountMatches(String text) =>
      RegExp(r'(?:[¥￥]\s*)?(\d+(?:\.\d{1,2})?)').allMatches(text).where((
        match,
      ) {
        final after = match.end < text.length ? text.substring(match.end) : '';
        return !RegExp(r'^[年月日号]').hasMatch(after);
      });

  static DateTime _parseDate(String text, DateTime today) {
    if (text.contains('昨天')) {
      return DateTime(today.year, today.month, today.day - 1);
    }
    if (text.contains('明天')) {
      return DateTime(today.year, today.month, today.day + 1);
    }
    if (text.contains('后天')) {
      return DateTime(today.year, today.month, today.day + 2);
    }
    final nextWeek = RegExp(r'下周([一二三四五六日天])').firstMatch(text);
    if (nextWeek != null) {
      final target = _weekday(nextWeek.group(1)!);
      return DateTime(
        today.year,
        today.month,
        today.day + (8 - today.weekday) + target - 1,
      );
    }
    final week = RegExp(r'(?:本)?周([一二三四五六日天])').firstMatch(text);
    if (week != null) {
      final target = _weekday(week.group(1)!);
      final delta = (target - today.weekday + 7) % 7;
      return DateTime(today.year, today.month, today.day + delta);
    }
    return today;
  }

  static int _weekday(String value) => switch (value) {
    '一' => 1,
    '二' => 2,
    '三' => 3,
    '四' => 4,
    '五' => 5,
    '六' => 6,
    _ => 7,
  };

  static Account? _matchAccount(String text, List<Account> accounts) {
    final direct = accounts
        .where((account) => text.contains(account.name))
        .firstOrNull;
    if (direct != null) return direct;
    final tokens = text.split(RegExp(r'[\s，,。]+'));
    for (final account in accounts) {
      if (account.name.length < 2) continue;
      if (tokens.any((token) => _distance(token, account.name) <= 1)) {
        return account;
      }
    }
    return null;
  }

  static String? _matchCategory(String text, TransactionType type) {
    for (final entry in _categoryWords.entries) {
      final category = Categories.find(entry.key);
      if (category?.type == type && entry.value.any(text.contains)) {
        return entry.key;
      }
    }
    final tokens = text.split(RegExp(r'[\s，,。]+'));
    for (final category in Categories.all.where((item) => item.type == type)) {
      if (category.name.length >= 2 &&
          tokens.any((token) => _distance(token, category.name) <= 1)) {
        return category.id;
      }
    }
    return null;
  }

  static String? _extractMerchant(
    String input, {
    required String? amountText,
    required List<Account> accounts,
  }) {
    var value = input;
    if (amountText != null) value = value.replaceFirst(amountText, ' ');
    value = value.replaceAll(
      RegExp(r'昨天|今天|明天|后天|下周[一二三四五六日天]|(?:本)?周[一二三四五六日天]'),
      ' ',
    );
    for (final account in accounts) {
      value = value.replaceAll(account.name, ' ');
    }
    for (final words in _categoryWords.values) {
      for (final word in words) {
        value = value.replaceAll(word, ' ');
      }
    }
    for (final word in [..._incomeWords, '支出', '花了', '支付']) {
      value = value.replaceAll(word, ' ');
    }
    value = value.replaceAll(RegExp(r'[，,。]'), ' ').trim();
    value = value.replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty || value.length > 200) return null;
    return value;
  }

  static int _distance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var previous = List<int>.generate(b.length + 1, (index) => index);
    for (var i = 0; i < a.length; i++) {
      final current = <int>[i + 1];
      for (var j = 0; j < b.length; j++) {
        current.add(
          [
            current[j] + 1,
            previous[j + 1] + 1,
            previous[j] + (a[i] == b[j] ? 0 : 1),
          ].reduce((left, right) => left < right ? left : right),
        );
      }
      previous = current;
    }
    return previous.last;
  }
}
