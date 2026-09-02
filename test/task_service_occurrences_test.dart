import 'dart:io';

import 'package:app_task/database/database_helper.dart';
import 'package:app_task/models/subtask.dart';
import 'package:app_task/models/task.dart';
import 'package:app_task/services/task_service.dart';
import 'package:app_task/utils/weekday_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'helpers/test_database.dart';

void main() {
  setUpAll(() {
    initTestDatabase();
  });

  group('Recorrência', () {
    late TaskService service;
    late DatabaseHelper db;
    late Directory dir;

    setUp(() async {
      final ctx = await createTestTaskService();
      service = ctx.service;
      db = ctx.db;
      dir = ctx.dir;

      await createRecurringWithSubtasks(
        service,
        title: 'Treino',
        recurringDays: '1,3,5',
        time: '15:00',
      );
    });

    tearDown(() async {
      await disposeTestTaskService(db: db, dir: dir);
    });

    test('aparece seg/qua/sex na semana 31/08–06/09', () async {
      expect(await taskAppearsOn(service, date(2026, 8, 31), 'Treino'), isTrue);
      expect(await taskAppearsOn(service, date(2026, 9, 2), 'Treino'), isTrue);
      expect(await taskAppearsOn(service, date(2026, 9, 4), 'Treino'), isTrue);
    });

    test('não aparece ter/qui na semana 31/08–06/09', () async {
      expect(await taskAppearsOn(service, date(2026, 9, 1), 'Treino'), isFalse);
      expect(await taskAppearsOn(service, date(2026, 9, 3), 'Treino'), isFalse);
    });

    test('aparece na semana seguinte (07/09, 09/09, 11/09)', () async {
      expect(await taskAppearsOn(service, date(2026, 9, 7), 'Treino'), isTrue);
      expect(await taskAppearsOn(service, date(2026, 9, 9), 'Treino'), isTrue);
      expect(await taskAppearsOn(service, date(2026, 9, 11), 'Treino'), isTrue);
    });

    test('horário efetivo padrão é 15:00', () async {
      final task = await loadTaskOnDate(service, date(2026, 8, 31), 'Treino');
      expect(task?.effectiveTime, '15:00');
    });
  });

  group('Override de horário', () {
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

      await service.updateOccurrence(
        taskId,
        date(2026, 9, 2),
        time: '17:00',
      );
    });

    tearDown(() async {
      await disposeTestTaskService(db: db, dir: dir);
    });

    test('override afeta somente a data alterada', () async {
      expect(
        (await loadTaskOnDate(service, date(2026, 8, 31), 'Treino'))
            ?.effectiveTime,
        '15:00',
      );
      expect(
        (await loadTaskOnDate(service, date(2026, 9, 2), 'Treino'))
            ?.effectiveTime,
        '17:00',
      );
      expect(
        (await loadTaskOnDate(service, date(2026, 9, 4), 'Treino'))
            ?.effectiveTime,
        '15:00',
      );
      expect(
        (await loadTaskOnDate(service, date(2026, 9, 9), 'Treino'))
            ?.effectiveTime,
        '15:00',
      );
    });

    test('regra em tasks.time permanece 15:00', () async {
      final rule = await db.getTaskById(taskId);
      expect(rule?.time, '15:00');
    });
  });

  group('Override de título e descrição', () {
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
        description: 'treino normal',
      );

      await service.updateOccurrence(
        taskId,
        date(2026, 9, 2),
        title: 'Treino pesado',
        description: 'foco em força',
      );
    });

    tearDown(() async {
      await disposeTestTaskService(db: db, dir: dir);
    });

    test('overrides isolados por data', () async {
      final mon = await loadTaskOnDate(service, date(2026, 8, 31), 'Treino');
      expect(mon?.effectiveTitle, 'Treino');
      expect(mon?.effectiveDescription, 'treino normal');

      final wed = await loadTaskOnDate(
        service,
        date(2026, 9, 2),
        'Treino pesado',
      );
      expect(wed?.effectiveTitle, 'Treino pesado');
      expect(wed?.effectiveDescription, 'foco em força');

      final fri = await loadTaskOnDate(service, date(2026, 9, 4), 'Treino');
      expect(fri?.effectiveTitle, 'Treino');
      expect(fri?.effectiveDescription, 'treino normal');
    });

    test('regra em tasks não foi alterada', () async {
      final rule = await db.getTaskById(taskId);
      expect(rule?.title, 'Treino');
      expect(rule?.description, 'treino normal');
    });
  });

  group('Cancelamento de ocorrência', () {
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
      );

      await service.cancelOccurrence(taskId, date(2026, 9, 2));
    });

    tearDown(() async {
      await disposeTestTaskService(db: db, dir: dir);
    });

    test('ocorrência cancelada some; demais permanecem', () async {
      expect(await taskAppearsOn(service, date(2026, 8, 31), 'Treino'), isTrue);
      expect(await taskAppearsOn(service, date(2026, 9, 2), 'Treino'), isFalse);
      expect(await taskAppearsOn(service, date(2026, 9, 4), 'Treino'), isTrue);
      expect(await taskAppearsOn(service, date(2026, 9, 7), 'Treino'), isTrue);
      expect(await taskAppearsOn(service, date(2026, 9, 9), 'Treino'), isTrue);
    });

    test('regra recorrente continua em tasks', () async {
      final rule = await db.getTaskById(taskId);
      expect(rule, isNotNull);
      expect(rule!.isRecurring, isTrue);
      expect(rule.recurringDays, '1,3,5');
    });

    test('cancelamento não recria ocorrência virtual cancelada', () async {
      final occurrence = await db.getOccurrence(
        taskId,
        WeekdayUtils.toDateString(date(2026, 9, 2)),
      );
      expect(occurrence?.cancelled, isTrue);

      for (var i = 0; i < 3; i++) {
        expect(
          await taskAppearsOn(service, date(2026, 9, 2), 'Treino'),
          isFalse,
        );
      }
    });
  });

  group('Conclusão de recorrência por data', () {
    late TaskService service;
    late DatabaseHelper db;
    late Directory dir;
    late int taskId;
    late Task taskTemplate;

    setUp(() async {
      final ctx = await createTestTaskService();
      service = ctx.service;
      db = ctx.db;
      dir = ctx.dir;

      taskId = await createRecurringWithSubtasks(
        service,
        title: 'Treino',
        recurringDays: '1,3',
      );
      taskTemplate = (await db.getTaskById(taskId))!;
    });

    tearDown(() async {
      await disposeTestTaskService(db: db, dir: dir);
    });

    Future<Task> taskOn(DateTime day) async {
      return (await loadTaskOnDate(service, day, 'Treino'))!;
    }

    test('conclusão isolada por ocorrência', () async {
      await service.toggleTaskCompleted(
        task: taskTemplate,
        completed: true,
        date: date(2026, 8, 31),
      );

      expect((await taskOn(date(2026, 8, 31))).completed, isTrue);
      expect((await taskOn(date(2026, 9, 2))).completed, isFalse);

      await service.toggleTaskCompleted(
        task: taskTemplate,
        completed: true,
        date: date(2026, 9, 2),
      );

      expect((await taskOn(date(2026, 8, 31))).completed, isTrue);
      expect((await taskOn(date(2026, 9, 2))).completed, isTrue);

      await service.toggleTaskCompleted(
        task: taskTemplate,
        completed: false,
        date: date(2026, 8, 31),
      );

      expect((await taskOn(date(2026, 8, 31))).completed, isFalse);
      expect((await taskOn(date(2026, 9, 2))).completed, isTrue);
    });

    test('tasks.completed da regra não é alterado', () async {
      await service.toggleTaskCompleted(
        task: taskTemplate,
        completed: true,
        date: date(2026, 8, 31),
      );
      final rule = await db.getTaskById(taskId);
      expect(rule?.completed, isFalse);
    });
  });

  group('Subtarefas recorrentes por ocorrência', () {
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
        recurringDays: '1,3',
        subtaskTitles: ['Supino', 'Remada', 'Agachamento'],
      );
    });

    tearDown(() async {
      await disposeTestTaskService(db: db, dir: dir);
    });

    Future<Subtask> supinoOn(DateTime day) async {
      final task = (await loadTaskOnDate(service, day, 'Treino'))!;
      return findSubtask(task, 'Supino')!;
    }

    test('conclusão de subtarefa isolada por data', () async {
      final monTask =
          (await loadTaskOnDate(service, date(2026, 8, 31), 'Treino'))!;
      final supinoId = findSubtask(monTask, 'Supino')!.id!;

      await service.toggleSubtaskCompleted(
        supinoId,
        date(2026, 8, 31),
        true,
        isRecurring: true,
      );

      final mon = await loadTaskOnDate(service, date(2026, 8, 31), 'Treino')!;
      expect(findSubtask(mon, 'Supino')!.completed, isTrue);
      expect(findSubtask(mon, 'Remada')!.completed, isFalse);
      expect(findSubtask(mon, 'Agachamento')!.completed, isFalse);

      final wed = await loadTaskOnDate(service, date(2026, 9, 2), 'Treino')!;
      expect(findSubtask(wed, 'Supino')!.completed, isFalse);
      expect(findSubtask(wed, 'Remada')!.completed, isFalse);
      expect(findSubtask(wed, 'Agachamento')!.completed, isFalse);

      await service.toggleSubtaskCompleted(
        supinoId,
        date(2026, 9, 2),
        true,
        isRecurring: true,
      );

      expect((await supinoOn(date(2026, 8, 31))).completed, isTrue);
      expect((await supinoOn(date(2026, 9, 2))).completed, isTrue);

      await service.toggleSubtaskCompleted(
        supinoId,
        date(2026, 8, 31),
        false,
        isRecurring: true,
      );

      expect((await supinoOn(date(2026, 8, 31))).completed, isFalse);
      expect((await supinoOn(date(2026, 9, 2))).completed, isTrue);
    });

    test('subtasks.completed do template permanece false', () async {
      final monTask =
          (await loadTaskOnDate(service, date(2026, 8, 31), 'Treino'))!;
      final supinoId = findSubtask(monTask, 'Supino')!.id!;

      await service.toggleSubtaskCompleted(
        supinoId,
        date(2026, 8, 31),
        true,
        isRecurring: true,
      );

      final templates = await db.getSubtasks(taskId);
      expect(templates.every((s) => s.completed == false), isTrue);
    });
  });

  group('Tarefa avulsa', () {
    late TaskService service;
    late DatabaseHelper db;
    late Directory dir;
    late int taskId;

    setUp(() async {
      final ctx = await createTestTaskService();
      service = ctx.service;
      db = ctx.db;
      dir = ctx.dir;

      taskId = await service.createTask(
        oneOffTask(title: 'Entregar trabalho', dueDate: '2026-09-03'),
        [],
      );
    });

    tearDown(() async {
      await disposeTestTaskService(db: db, dir: dir);
    });

    test('concluir não arquiva e permanece visível na data', () async {
      final task = (await db.getTaskById(taskId))!;
      await service.toggleTaskCompleted(
        task: task,
        completed: true,
        date: date(2026, 9, 3),
      );

      final stored = await db.getTaskById(taskId);
      expect(stored?.completed, isTrue);
      expect(stored?.archived, isFalse);

      final visible = await service.getTasksForDate(date(2026, 9, 3));
      expect(containsTitle(visible, 'Entregar trabalho'), isTrue);
      expect(findByTitle(visible, 'Entregar trabalho')!.completed, isTrue);
    });

    test('aparece somente na due_date', () async {
      expect(
        await taskAppearsOn(service, date(2026, 9, 3), 'Entregar trabalho'),
        isTrue,
      );
      expect(
        await taskAppearsOn(service, date(2026, 9, 10), 'Entregar trabalho'),
        isFalse,
      );
      expect(
        await taskAppearsOn(service, date(2026, 8, 27), 'Entregar trabalho'),
        isFalse,
      );
    });
  });

  group('Navegação entre semanas via getTasksForDate', () {
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

    test('semanas diferentes retornam datas corretas sem alterar regra', () async {
      final week1Start = date(2026, 8, 31);
      final week2Start = WeekdayUtils.addWeeks(week1Start, 1);

      final w1Wed = WeekdayUtils.dateInWeek(week1Start, DateTime.wednesday);
      final w2Wed = WeekdayUtils.dateInWeek(week2Start, DateTime.wednesday);

      expect(
        (await loadTaskOnDate(service, w1Wed, 'Treino'))?.effectiveTime,
        '15:00',
      );
      expect(
        (await loadTaskOnDate(service, w2Wed, 'Treino'))?.effectiveTime,
        '15:00',
      );

      await service.updateOccurrence(taskId, w1Wed, time: '17:00');

      expect(
        (await loadTaskOnDate(service, w1Wed, 'Treino'))?.effectiveTime,
        '17:00',
      );
      expect(
        (await loadTaskOnDate(service, w2Wed, 'Treino'))?.effectiveTime,
        '15:00',
      );
    });
  });
}
