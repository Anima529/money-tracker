import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/providers/transaction_providers.dart';
import '../data/drift_merchant_rule_repository.dart';
import '../data/merchant_rule_dao.dart';
import '../domain/merchant_rule.dart';

final merchantRuleRepositoryProvider = Provider<MerchantRuleRepository>(
  (ref) =>
      DriftMerchantRuleRepository(MerchantRuleDao(ref.watch(databaseProvider))),
);

final merchantRulesProvider = StreamProvider<List<MerchantRule>>(
  (ref) => ref.watch(merchantRuleRepositoryProvider).watchAll(),
);
