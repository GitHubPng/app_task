import 'dart:io';

import 'package:app_task/database/database_helper.dart';
import 'package:app_task/models/subtask.dart';
import 'package:app_task/models/task.dart';
import 'package:app_task/services/task_service.dart';
import 'package:app_task/utils/weekday_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

void main() {
  setUpAll(() {
    initTestDatabase();
  });

  group('Versionamento de regra recorrente', () {
    late TaskService service;
    late DatabaseHelper db;
    late Directory dir;
    late int taskId;

    setUp(() async {
      final ctx = await createTestTaskService();
      service = ctx.service;
      db = ctx.db;
      dir = ctx.dir;

      taskId = await createRecurringWithSubtasks(
        service,
        title: 'Treino',
        recurringDays: '1,3,5',
        time: '15:00',
        description: 'treino normal',
      );
    });

    tearDown(() async {
      await disposeTestTaskService(db: db, dir: dir);
    });

    test('altera SEG/QUA/SEX para TER/QUI a partir de 05/09', () async {
      await service.updateRecurrenceRule(
        taskId: taskId,
        effectiveFrom: date(2026, 9, 5),
        recurringDays: '2,4',
        title: 'Treino',
        description: 'treino normal',
        time: '15:00',
      );

      expect(await taskAppearsOn(service, date(2026, 8, 31), 'Treino'), isTrue);
      expect(await taskAppearsOn(service, date(2026, 9, 2), 'Treino'), isTrue);
      expect(await taskAppearsOn(service, date(2026, 9, 4), 'Treino'), isTrue);

      expect(await taskAppearsOn(service, date(2026, 9, 5), 'Treino'), isFalse);
      expect(await taskAppearsOn(service, date(2026, 9, 8), 'Treino'), isTrue);
      expect(await taskAppearsOn(service, date(2026, 9, 10), 'Treino'), isTrue);
      expect(await taskAppearsOn(service, date(2026, 9, 9), 'Treino'), isFalse);
    });

    test('preserva override histórico após mudança de regra', () async {
      await service.updateOccurrence(
        taskId,
        date(2026, 9, 2),
        time: '17:00',
      );

      await service.updateRecurrenceRule(
        taskId: taskId,
        effectiveFrom: date(2026, 9, 5),
        recurringDays: '2,4',
        title: 'Treino',
        time: '15:00',
      );

      expect(
        (await loadTaskOnDate(service, date(2026, 9, 2), 'Treino'))?.effectiveTime,
        '17:00',
      );
      expect(
        (await loadTaskOnDate(service, date(2026, 9, 8), 'Treino'))?.effectiveTime,
        '15:00',
      );
    });

    test('preserva cancelamento histórico após mudança de regra', () async {
      await service.cancelOccurrence(taskId, date(2026, 9, 4));

      await service.updateRecurrenceRule(
        taskId: taskId,
        effectiveFrom: date(2026, 9, 5),
        recurringDays: '2,4',
        title: 'Treino',
        time: '15:00',
      );

      expect(await taskAppearsOn(service, date(2026, 9, 4), 'Treino'), isFalse);
      expect(await taskAppearsOn(service, date(2026, 9, 8), 'Treino'), isTrue);
    });

    test('preserva conclusão histórica após mudança de regra', () async {
      final template = (await db.getTaskById(taskId))!;
      await service.toggleTaskCompleted(
        task: template,
        completed: true,
        date: date(2026, 8, 31),
      );

      await service.updateRecurrenceRule(
        taskId: taskId,
        effectiveFrom: date(2026, 9, 5),
        recurringDays: '2,4',
        title: 'Treino',
        time: '15:00',
      );

      expect(
        (await loadTaskOnDate(service, date(2026, 8, 31), 'Treino'))!.completed,
        isTrue,
      );
      expect(
        (await loadTaskOnDate(service, date(2026, 9, 8), 'Treino'))!.completed,
        isFalse,
      );
    });

    test('altera título/descrição/horário padrão sem afetar override', () async {
      await service.updateOccurrence(
        taskId,
        date(2026, 9, 2),
        title: 'Treino pesado',
        time: '17:00',
      );

      await service.updateRecurrenceRule(
        taskId: taskId,
        effectiveFrom: date(2026, 9, 5),
        recurringDays: '2,4',
        title: 'Treino leve',
        description: 'foco em cardio',
        time: '16:00',
      );

      expect(
        (await loadTaskOnDate(service, date(2026, 9, 2), 'Treino pesado'))
            ?.effectiveTime,
        '17:00',
      );

      final future = await loadTaskOnDate(service, date(2026, 9, 8), 'Treino leve');
      expect(future?.effectiveTitle, 'Treino leve');
      expect(future?.effectiveDescription, 'foco em cardio');
      expect(future?.effectiveTime, '16:00');
    });

    test('editar rotina não altera tasks.time da regra anterior no histórico', () async {
      await service.updateRecurrenceRule(
        taskId: taskId,
        effectiveFrom: date(2026, 9, 5),
        recurringDays: '2,4',
        title: 'Treino',
        time: '16:00',
      );

      expect(
        (await loadTaskOnDate(service, date(2026, 9, 2), 'Treino'))?.effectiveTime,
        '15:00',
      );

      final stored = await db.getTaskById(taskId);
      expect(stored?.time, '16:00');
    });
  });

  group('Conversão avulsa → recorrente', () {
    late TaskService service;
    late DatabaseHelper db;
    late Directory dir;

    setUp(() async {
      final ctx = await createTestTaskService();
      service = ctx.service;
      db = ctx.db;
      dir = ctx.dir;
    });

    tearDown(() async {
      await disposeTestTaskService(db: db, dir: dir);
    });

    test('preserva ocorrência original e conclusão na due_date', () async {
      final taskId = await service.createTask(
        oneOffTask(title: 'Estudar Flutter', dueDate: '2026-09-03'),
        [],
      );

      final task = (await db.getTaskById(taskId))!;
      await service.toggleTaskCompleted(
        task: task,
        completed: true,
        date: date(2026, 9, 3),
      );

      await service.convertToRecurring(
        task: task,
        effectiveFrom: date(2026, 9, 3),
        recurringDays: '1,3,5',
        title: 'Estudar Flutter',
        subtasks: [],
      );

      expect(await taskAppearsOn(service, date(2026, 9, 3), 'Estudar Flutter'), isTrue);
      expect(
        (await loadTaskOnDate(service, date(2026, 9, 3), 'Estudar Flutter'))!
            .completed,
        isTrue,
      );
      expect(await taskAppearsOn(service, date(2026, 9, 4), 'Estudar Flutter'), isFalse);
      expect(await taskAppearsOn(service, date(2026, 9, 5), 'Estudar Flutter'), isTrue);
    });

    test('ancora due_date quando weekday não está na nova regra', () async {
      final taskId = await service.createTask(
        oneOffTask(title: 'Estudar Flutter', dueDate: '2026-09-03'),
        [],
      );
      final task = (await db.getTaskById(taskId))!;

      await service.convertToRecurring(
        task: task,
        effectiveFrom: date(2026, 9, 3),
        recurringDays: '1,3,5',
        title: 'Estudar Flutter',
        subtasks: [],
      );

      // 03/09 é quinta — fora de seg/qua/sex, mas deve permanecer visível.
      expect(await taskAppearsOn(service, date(2026, 9, 3), 'Estudar Flutter'), isTrue);
      expect(await taskAppearsOn(service, date(2026, 9, 7), 'Estudar Flutter'), isTrue);
    });
  });

  group('Ocorrências futuras após mudança de regra', () {
    late TaskService service;
    late DatabaseHelper db;
    late Directory dir;
    late int taskId;

    setUp(() async {
      final ctx = await createTestTaskService();
      service = ctx.service;
      db = ctx.db;
      dir = ctx.dir;

      taskId = await createRecurringWithSubtasks(
        service,
        title: 'Treino',
        recurringDays: '1,3,5',
        time: '15:00',
      );
    });

    tearDown(() async {
      await disposeTestTaskService(db: db, dir: dir);
    });

    test('calcula corretamente semanas posteriores', () async {
      await service.updateRecurrenceRule(
        taskId: taskId,
        effectiveFrom: date(2026, 9, 5),
        recurringDays: '2,4',
        title: 'Treino',
        time: '15:00',
      );

      expect(await taskAppearsOn(service, date(2026, 9, 8), 'Treino'), isTrue);
      expect(await taskAppearsOn(service, date(2026, 9, 10), 'Treino'), isTrue);
      expect(await taskAppearsOn(service, date(2026, 9, 15), 'Treino'), isTrue);
      expect(await taskAppearsOn(service, date(2026, 9, 17), 'Treino'), isTrue);
      expect(await taskAppearsOn(service, date(2026, 9, 14), 'Treino'), isFalse);
      expect(await taskAppearsOn(service, date(2026, 9, 16), 'Treino'), isFalse);
    });
  });
}
