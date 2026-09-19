import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/providers/transaction_providers.dart';
import '../data/account_dao.dart';
import '../data/drift_account_repository.dart';
import '../domain/account.dart';
import '../domain/account_repository.dart';

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => DriftAccountRepository(AccountDao(ref.watch(databaseProvider))),
);

final accountsProvider = StreamProvider<List<Account>>(
  (ref) => ref.watch(accountRepositoryProvider).watchAll(),
);

final accountBalancesProvider = StreamProvider<List<AccountBalance>>(
  (ref) => ref.watch(accountRepositoryProvider).watchBalances(),
);
