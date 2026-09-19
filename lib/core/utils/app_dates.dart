import 'package:intl/intl.dart';

abstract final class AppDates {
  static DateTime dayStart(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  // 用日历日期推进，避免夏令时切换时“加 24 小时”跨错日期。
  static DateTime nextDay(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day + 1);
  }

  static DateTime monthStart(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month);
  }

  static DateTime nextMonth(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month + 1);
  }

  static String dayLabel(DateTime date) =>
      DateFormat('yyyy/MM/dd').format(date.toLocal());
  static String monthLabel(DateTime date) =>
      DateFormat('yyyy年M月').format(date.toLocal());
}
