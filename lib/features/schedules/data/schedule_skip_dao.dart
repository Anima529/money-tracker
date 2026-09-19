import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class ScheduleSkipDao {
  const ScheduleSkipDao(this.database);

  final AppDatabase database;

  Future<int> insert(ScheduleSkipsCompanion value) =>
      database.into(database.scheduleSkips).insert(value);

  Future<int> delete(int scheduleId, DateTime scheduledFor) =>
      (database.delete(database.scheduleSkips)..where(
            (row) =>
                row.scheduleId.equals(scheduleId) &
                row.scheduledFor.equals(scheduledFor),
          ))
          .go();

  Future<List<ScheduleSkipRow>> getAll() => (database.select(
    database.scheduleSkips,
  )..orderBy([(row) => OrderingTerm.asc(row.scheduledFor)])).get();

  Stream<List<ScheduleSkipRow>> watchAll() => (database.select(
    database.scheduleSkips,
  )..orderBy([(row) => OrderingTerm.asc(row.scheduledFor)])).watch();
}
