import 'schedule.dart';
import 'schedule_instance.dart';

abstract interface class ScheduleRepository {
  Future<int> add(ScheduleDraft draft);
  Future<bool> update(int id, ScheduleDraft draft);
  Future<bool> delete(int id);
  Future<List<Schedule>> getAll({bool enabledOnly = false});
  Stream<List<Schedule>> watchAll({bool enabledOnly = false});
  Future<void> skip(int scheduleId, DateTime scheduledFor);
  Future<bool> unskip(int scheduleId, DateTime scheduledFor);
  Future<List<ScheduleSkip>> getSkips();
  Stream<List<ScheduleSkip>> watchSkips();
}
