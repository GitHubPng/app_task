import 'dart:io';

import 'package:app_task/database/database_helper.dart';
import 'package:app_task/models/task.dart';
import 'package:app_task/services/stats.dart';
import 'package:app_task/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

Task t({bool done = false}) => Task(
      title: 'x',
      createdAt: '2026-01-01T00:00:00.000',
      completed: done,
    );

void main() {
  group('computeWeekStats', () {
    final today = DateTime(2026, 9, 2); // quarta

    final stats = computeWeekStats({
      DateTime(2026, 8, 31): [t(done: true), t()],
      DateTime(2026, 9, 1): [t(done: true), t(done: true)],
      DateTime(2026, 9, 2): [t()],
      DateTime(2026, 9, 3): [t(done: true)], // futuro: ignorado
    }, today);

    test('8 semanas, mais recente primeiro', () {
      expect(stats.length, 8);
      expect(stats[0].weekStart, DateTime(2026, 8, 31));
      expect(stats[1].weekStart, DateTime(2026, 8, 24));
      expect(stats[7].weekStart, DateTime(2026, 7, 13));
    });

    test('soma até hoje, ignorando o futuro', () {
      expect(stats[0].total, 5);
      expect(stats[0].done, 3);
      expect(stats[0].rate, closeTo(0.6, 1e-9));
    });

    test('semana sem tarefas não tem taxa', () {
      expect(stats[1].total, 0);
      expect(stats[1].rate, isNull);
    });
  });

  group('weekDelta', () {
    WeekStats w(int done, int total) =>
        WeekStats(weekStart: DateTime(2026), total: total, done: done);

    test('pontos percentuais entre as duas semanas mais recentes', () {
      expect(weekDelta([w(6, 10), w(5, 10)]), 10);
      expect(weekDelta([w(4, 10), w(5, 10)]), -10);
    });

    test('nulo sem dados em alguma das duas', () {
      expect(weekDelta([w(6, 10), w(0, 0)]), isNull);
      expect(weekDelta([w(6, 10)]), isNull);
    });
  });

  group('weeklyStats', () {
    late TaskService service;
    late DatabaseHelper db;
    late Directory dir;
    late int treinoId;

    setUpAll(initTestDatabase);

    setUp(() async {
      final ctx = await createTestTaskService();
      service = ctx.service;
      db = ctx.db;
      dir = ctx.dir;
      treinoId = await createRecurringWithSubtasks(service, title: 'Treino');
      final mon = (await loadTaskOnDate(service, date(2026, 8, 31), 'Treino'))!;
      await service.toggleTaskCompleted(
        task: mon,
        completed: true,
        date: date(2026, 8, 31),
      );
      await service.cancelOccurrence(treinoId, date(2026, 9, 2));
    });

    tearDown(() async {
      await disposeTestTaskService(db: db, dir: dir);
    });

    test('cancelada não conta; só até hoje', () async {
      final stats = await service.weeklyStats(today: date(2026, 9, 4));
      // seg 31/08 (feita) + sex 04/09; qua 02/09 cancelada.
      expect(stats[0].total, 2);
      expect(stats[0].done, 1);
    });

    test('avulsa conta na própria data', () async {
      await service.createTask(
        oneOffTask(title: 'Dentista', dueDate: '2026-09-03'),
        [],
      );
      final stats = await service.weeklyStats(today: date(2026, 9, 4));
      expect(stats[0].total, 3);
    });

    test('nova versão da rotina não altera semana anterior', () async {
      await service.updateRecurrenceRule(
        taskId: treinoId,
        effectiveFrom: date(2026, 9, 8),
        recurringDays: '2,4',
        title: 'Treino',
      );
      final stats = await service.weeklyStats(today: date(2026, 9, 10));
      expect(stats[1].total, 2); // semana de 31/08 intacta
      // seg 07/09 ainda na regra antiga; ter 08/09 e qui 10/09 na nova.
      expect(stats[0].total, 3);
    });
  });
}
