import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/drift_transaction_repository.dart';
import '../data/transaction_dao.dart';
import '../domain/transaction.dart';
import '../domain/transaction_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});
final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) =>
      DriftTransactionRepository(TransactionDao(ref.watch(databaseProvider))),
);
final transactionsProvider = StreamProvider<List<Transaction>>(
  (ref) => ref
      .watch(transactionRepositoryProvider)
      .watchAll(status: TransactionStatus.confirmed),
);
final allTransactionsProvider = StreamProvider<List<Transaction>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchAll(),
);
final plannedTransactionsProvider = StreamProvider<List<Transaction>>(
  (ref) => ref
      .watch(transactionRepositoryProvider)
      .watchAll(status: TransactionStatus.planned),
);
final recentTransactionsProvider = StreamProvider<List<Transaction>>(
  (ref) => ref
      .watch(transactionRepositoryProvider)
      .watchAll(status: TransactionStatus.confirmed, limit: 5),
);
final trashTransactionsProvider = StreamProvider<List<Transaction>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchTrash(),
);
final monthlyTransactionsProvider =
    StreamProvider.family<List<Transaction>, DateTime>(
      (ref, month) =>
          ref.watch(transactionRepositoryProvider).watchMonth(month),
    );
