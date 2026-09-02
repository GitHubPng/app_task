import 'package:app_task/utils/weekday_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

void main() {
  final weekStartAug31 = date(2026, 8, 31);

  group('WeekdayUtils.weekStart', () {
    test('weekStart(2026-09-02) retorna segunda 2026-08-31', () {
      final result = WeekdayUtils.weekStart(date(2026, 9, 2));
      expect(result, date(2026, 8, 31));
    });
  });

  group('WeekdayUtils.dateInWeek', () {
    test('mapeia todos os dias da semana iniciando em 31/08', () {
      expect(
        WeekdayUtils.dateInWeek(weekStartAug31, DateTime.monday),
        date(2026, 8, 31),
      );
      expect(
        WeekdayUtils.dateInWeek(weekStartAug31, DateTime.tuesday),
        date(2026, 9, 1),
      );
      expect(
        WeekdayUtils.dateInWeek(weekStartAug31, DateTime.wednesday),
        date(2026, 9, 2),
      );
      expect(
        WeekdayUtils.dateInWeek(weekStartAug31, DateTime.thursday),
        date(2026, 9, 3),
      );
      expect(
        WeekdayUtils.dateInWeek(weekStartAug31, DateTime.friday),
        date(2026, 9, 4),
      );
      expect(
        WeekdayUtils.dateInWeek(weekStartAug31, DateTime.saturday),
        date(2026, 9, 5),
      );
      expect(
        WeekdayUtils.dateInWeek(weekStartAug31, DateTime.sunday),
        date(2026, 9, 6),
      );
    });
  });

  group('WeekdayUtils.addWeeks', () {
    test('addWeeks(31/08, 1) == 07/09', () {
      expect(
        WeekdayUtils.addWeeks(weekStartAug31, 1),
        date(2026, 9, 7),
      );
    });

    test('addWeeks(31/08, -1) == 24/08', () {
      expect(
        WeekdayUtils.addWeeks(weekStartAug31, -1),
        date(2026, 8, 24),
      );
    });
  });

  group('WeekdayUtils.toDateString', () {
    test('formata YYYY-MM-DD', () {
      expect(
        WeekdayUtils.toDateString(date(2026, 9, 2)),
        '2026-09-02',
      );
    });
  });
}
