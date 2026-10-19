import 'dart:io';

import 'package:app_task/database/database_helper.dart';
import 'package:app_task/models/task.dart';
import 'package:app_task/services/task_service.dart';
import 'package:app_task/utils/time_range.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'helpers/test_database.dart';

void main() {
  setUpAll(() {
    initTestDatabase();
  });

  group('Migration → v6', () {
    late Directory dir;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('app_task_migration_v6_');
      dbHelper = DatabaseHelper.test(await createV2DatabaseFixture(dir));
    });

    tearDown(() async {
      await dbHelper.closeForTest();
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('cria colunas de intervalo e preserva dados', () async {
      final db = await dbHelper.database;
      expect(
        Sqflite.firstIntValue(await db.rawQuery('PRAGMA user_version')),
        6,
      );
      for (final table in [
        'tasks',
        'task_recurrence_rules',
        'task_occurrences',
      ]) {
        final cols = (await db.rawQuery('PRAGMA table_info($table)'))
            .map((r) => r['name'])
            .toSet();
        expect(cols, containsAll(['end_time', 'break_start', 'break_end']));
      }

      final service = TaskService(db: dbHelper);
      final treino =
          (await loadTaskOnDate(service, date(2026, 8, 31), 'Treino v2'))!;
      expect(treino.effectiveTime, '15:00');
      expect(treino.effectiveEndTime, isNull);
      expect(treino.effectiveRange.hasEnd, isFalse);
    });
  });

  group('Intervalo no service', () {
    late TaskService service;
    late DatabaseHelper db;
    late Directory dir;
    late int trabalhoId;

    setUp(() async {
      final ctx = await createTestTaskService();
      service = ctx.service;
      db = ctx.db;
      dir = ctx.dir;
      trabalhoId = await service.createTask(
        Task(
          title: 'Trabalho',
          createdAt: '2026-01-01T00:00:00.000',
          isRecurring: true,
          recurringDays: '1,2,3,4,5',
          time: '08:00',
          endTime: '15:00',
          breakStart: '12:00',
          breakEnd: '13:00',
        ),
        [],
      );
    });

    tearDown(() async {
      await disposeTestTaskService(db: db, dir: dir);
    });

    Future<TimeRange> rangeOn(DateTime day) async =>
        (await loadTaskOnDate(service, day, 'Trabalho'))!.effectiveRange;

    test('nova versão da rotina não altera semanas anteriores', () async {
      await service.updateRecurrenceRule(
        taskId: trabalhoId,
        effectiveFrom: date(2026, 9, 7),
        recurringDays: '1,2,3,4,5',
        title: 'Trabalho',
        time: '09:00',
        endTime: '16:00',
      );

      final before = await rangeOn(date(2026, 8, 31));
      expect(before.end, '15:00');
      expect(before.breakStart, '12:00');

      final after = await rangeOn(date(2026, 9, 7));
      expect(after.start, '09:00');
      expect(after.end, '16:00');
      expect(after.breakStart, isNull);
    });

    test('ocorrência muda o fim só naquela data', () async {
      await service.updateOccurrence(
        trabalhoId,
        date(2026, 9, 2),
        endTime: '14:00',
      );
      expect((await rangeOn(date(2026, 9, 2))).end, '14:00');
      expect((await rangeOn(date(2026, 9, 3))).end, '15:00');
    });

    test('ocorrência remove a pausa só naquela data', () async {
      await service.updateOccurrence(
        trabalhoId,
        date(2026, 9, 2),
        breakStart: '',
        breakEnd: '',
      );
      final wed = await rangeOn(date(2026, 9, 2));
      expect(wed.breakStart, isNull);
      expect(wed.breakEnd, isNull);
      expect((await rangeOn(date(2026, 9, 3))).breakStart, '12:00');
    });

    test('findConflicts respeita pausa e exclui a própria tarefa', () async {
      final mon = [date(2026, 8, 31)];
      final treino = await service.findConflicts(
        range: const TimeRange(start: '14:00'),
        dates: mon,
      );
      expect(treino.map((t) => t.title), ['Trabalho']);
      expect(treino.single.occurrenceDate, '2026-08-31');

      final almoco = await service.findConflicts(
        range: const TimeRange(start: '12:00'),
        dates: mon,
      );
      expect(almoco, isEmpty);

      final self = await service.findConflicts(
        range: const TimeRange(start: '09:00', end: '10:00'),
        dates: mon,
        excludeTaskId: trabalhoId,
      );
      expect(self, isEmpty);
    });

    test('datesForRule devolve os dias da semana da vigência', () {
      expect(
        TaskService.datesForRule(date(2026, 9, 2), [1, 5]),
        [date(2026, 8, 31), date(2026, 9, 4)],
      );
    });
  });
}
