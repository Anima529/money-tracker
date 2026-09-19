import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/providers/transaction_providers.dart';
import '../data/drift_schedule_repository.dart';
import '../data/schedule_dao.dart';
import '../data/schedule_skip_dao.dart';
import '../domain/schedule.dart';
import '../domain/schedule_repository.dart';
import '../domain/schedule_instance.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => DriftScheduleRepository(
    ScheduleDao(ref.watch(databaseProvider)),
    ScheduleSkipDao(ref.watch(databaseProvider)),
  ),
);

final scheduleSkipsProvider = StreamProvider<List<ScheduleSkip>>(
  (ref) => ref.watch(scheduleRepositoryProvider).watchSkips(),
);

final schedulesProvider = StreamProvider<List<Schedule>>(
  (ref) => ref.watch(scheduleRepositoryProvider).watchAll(),
);
