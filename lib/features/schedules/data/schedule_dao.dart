import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class ScheduleDao {
  const ScheduleDao(this.database);

  /// 当前使用的 Drift 数据库。
  final AppDatabase database;

  Future<int> insert(SchedulesCompanion value) =>
      database.into(database.schedules).insert(value);

  Future<int> update(int id, SchedulesCompanion value) => (database.update(
    database.schedules,
  )..where((row) => row.id.equals(id))).write(value);

  Future<int> delete(int id) => (database.delete(
    database.schedules,
  )..where((row) => row.id.equals(id))).go();

  SimpleSelectStatement<Schedules, ScheduleRow> _query(bool enabledOnly) {
    final query = database.select(database.schedules);
    if (enabledOnly) query.where((row) => row.isEnabled.equals(true));
    query.orderBy([
      (row) => OrderingTerm.asc(row.nextDate),
      (row) => OrderingTerm.asc(row.id),
    ]);
    return query;
  }

  Future<List<ScheduleRow>> get({bool enabledOnly = false}) =>
      _query(enabledOnly).get();

  Stream<List<ScheduleRow>> watch({bool enabledOnly = false}) =>
      _query(enabledOnly).watch();
}
