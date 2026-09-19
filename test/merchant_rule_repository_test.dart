import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/features/quick_input/data/drift_merchant_rule_repository.dart';
import 'package:money_tracker/features/quick_input/data/merchant_rule_dao.dart';

void main() {
  late AppDatabase database;
  late DriftMerchantRuleRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftMerchantRuleRepository(MerchantRuleDao(database));
  });

  tearDown(() => database.close());

  test(
    'learning is an upsert that updates recommendation and use count',
    () async {
      await repository.learn(
        pattern: ' 瑞幸 ',
        category: 'food',
        accountId: 1,
        merchant: '瑞幸咖啡',
      );
      await repository.learn(
        pattern: '瑞幸',
        category: 'expense_other',
        accountId: 1,
        merchant: '瑞幸',
      );
      final rule = (await repository.getAll()).single;
      expect(rule.pattern, '瑞幸');
      expect(rule.category, 'expense_other');
      expect(rule.useCount, 2);
      expect(await repository.delete(rule.id), isTrue);
      expect(await repository.getAll(), isEmpty);
    },
  );
}
