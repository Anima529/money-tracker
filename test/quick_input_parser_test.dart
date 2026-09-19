import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/features/accounts/domain/account.dart';
import 'package:money_tracker/features/quick_input/domain/merchant_rule.dart';
import 'package:money_tracker/features/quick_input/domain/quick_input_parser.dart';
import 'package:money_tracker/features/transactions/domain/transaction.dart';

Account account(int id, String name) => Account(
  id: id,
  uuid: '10000000-0000-4000-8000-${id.toString().padLeft(12, '0')}',
  name: name,
  type: AccountType.other,
  initialBalance: 0,
  icon: 'wallet',
  color: 0xff000000,
  isSpendable: true,
  isArchived: false,
  sortOrder: id,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  const parser = QuickInputParser();
  final now = DateTime(2026, 9, 19);
  final accounts = [account(1, '支付宝'), account(2, '微信')];

  test('parses amount, category, account and income locally', () {
    final lunch = parser.parse(
      '午饭 28 支付宝',
      now: now,
      accounts: accounts,
      rules: const [],
    );
    expect(lunch.amount, 2800);
    expect(lunch.type, TransactionType.expense);
    expect(lunch.category, 'food');
    expect(lunch.accountId, 1);

    final salary = parser.parse(
      '工资 8500 微信',
      now: now,
      accounts: accounts,
      rules: const [],
    );
    expect(salary.amount, 850000);
    expect(salary.type, TransactionType.income);
    expect(salary.category, 'salary');
    expect(salary.accountId, 2);
  });

  test('future date becomes editable planned transaction', () {
    final result = parser.parse(
      '下周一房租 2500',
      now: now,
      accounts: accounts,
      rules: const [],
    );
    expect(result.date, DateTime(2026, 9, 21));
    expect(result.status, TransactionStatus.planned);
    expect(result.category, 'housing');
  });

  test('merchant rule wins and fuzzy account match tolerates one typo', () {
    final rule = MerchantRule(
      id: 7,
      pattern: '瑞幸',
      category: 'food',
      accountId: 2,
      merchant: '瑞幸咖啡',
      useCount: 3,
      lastUsedAt: now,
      createdAt: now,
      updatedAt: now,
    );
    final result = parser.parse(
      '瑞幸 16 支富宝',
      now: now,
      accounts: accounts,
      rules: [rule],
    );
    expect(result.amount, 1600);
    expect(result.category, 'food');
    expect(result.accountId, 2);
    expect(result.merchant, '瑞幸咖啡');
    expect(result.matchedRuleId, 7);
  });

  test('missing amount falls back without losing ordinary form', () {
    final result = parser.parse(
      '今天散步',
      now: now,
      accounts: accounts,
      rules: const [],
    );
    expect(result.hasAmount, isFalse);
    expect(result.date, now);
  });
}
