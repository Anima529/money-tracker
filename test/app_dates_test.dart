import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/utils/app_dates.dart';

void main() {
  test('day range uses local midnight and next calendar day', () {
    final date = DateTime(2024, 2, 29, 23, 59, 59);
    expect(AppDates.dayStart(date), DateTime(2024, 2, 29));
    expect(AppDates.nextDay(date), DateTime(2024, 3, 1));
  });
  test('month ranges cover leap years and year boundaries', () {
    expect(AppDates.monthStart(DateTime(2024, 2, 29)), DateTime(2024, 2));
    expect(AppDates.nextMonth(DateTime(2024, 2)), DateTime(2024, 3));
    expect(AppDates.nextMonth(DateTime(2025, 12, 31)), DateTime(2026, 1));
  });
  test('UTC inputs are interpreted in device local time', () {
    final utc = DateTime.utc(2026, 9, 30, 23);
    final local = utc.toLocal();
    expect(
      AppDates.dayStart(utc),
      DateTime(local.year, local.month, local.day),
    );
  });
  test('date labels are stable', () {
    expect(AppDates.dayLabel(DateTime(2026, 9, 7)), '2026/09/07');
    expect(AppDates.monthLabel(DateTime(2026, 9, 7)), '2026年9月');
  });
}
