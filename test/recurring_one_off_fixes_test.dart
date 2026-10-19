import 'dart:io';

import 'package:app_task/database/database_helper.dart';
import 'package:app_task/models/subtask.dart';
import 'package:app_task/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/test_database.dart';

void main() {
  setUpAll(() {
    initTestDatabase();
  });

  group('Migration → v5', () {
    late Directory dir;
    late DatabaseHelper dbHelper;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('app_task_migration_v5_');
      final path = await createV2DatabaseFixture(dir);

      final raw = await openDatabase(path, version: 2);
      await raw.insert('tasks', {
        'title': 'Avulsa sem data',
        'due_date': null,
        'created_at': '2026-03-10T09:30:00.000',
        'is_recurring': 0,
      });
      await raw.close();

      dbHelper = DatabaseHelper.test(path);
    });

    tearDown(() async {
      await dbHelper.closeForTest();
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('avulsa sem data recebe a data de criação e aparece no dia', () async {
      final db = await dbHelper.database;
      final row = (await db.query(
        'tasks',
        where: 'title = ?',
        whereArgs: ['Avulsa sem data'],
      ))
          .single;
      expect(row['due_date'], '2026-03-10');

      final service = TaskService(db: dbHelper);
      expect(
        await taskAppearsOn(service, date(2026, 3, 10), 'Avulsa sem data'),
        isTrue,
      );
    });

    test('arquivada volta ao seu dia como concluída', () async {
      final service = TaskService(db: dbHelper);
      final task =
          await loadTaskOnDate(service, date(2026, 8, 1), 'Arquivada v2');
      expect(task, isNotNull);
      expect(task!.completed, isTrue);
    });
  });

  group('Subtarefas preservadas na edição', () {
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

    test('editar rotina mantém histórico das etapas que continuam', () async {
      final taskId = await createRecurringWithSubtasks(
        service,
        title: 'Treino',
        subtaskTitles: ['Supino', 'Remada'],
      );

      final mon = (await loadTaskOnDate(service, date(2026, 8, 31), 'Treino'))!;
      await service.toggleSubtaskCompleted(
        findSubtask(mon, 'Supino')!.id!,
        date(2026, 8, 31),
        true,
        isRecurring: true,
      );

      // Remove Remada, renomeia Supino, adiciona Agachamento.
      final supino = findSubtask(mon, 'Supino')!;
      await service.updateRecurrenceRule(
        taskId: taskId,
        effectiveFrom: date(2026, 9, 7),
        recurringDays: '1,3,5',
        title: 'Treino',
        subtasks: [
          supino.copyWith(title: 'Supino reto'),
          Subtask(taskId: 0, title: 'Agachamento'),
        ],
      );

      final monAfter =
          (await loadTaskOnDate(service, date(2026, 8, 31), 'Treino'))!;
      expect(findSubtask(monAfter, 'Supino reto')!.id, supino.id);
      expect(findSubtask(monAfter, 'Supino reto')!.completed, isTrue);
      expect(findSubtask(monAfter, 'Remada'), isNull);
      expect(findSubtask(monAfter, 'Agachamento')!.completed, isFalse);
    });

    test('editar avulsa mantém ids e grava estado das etapas', () async {
      final taskId = await service.createTask(
        oneOffTask(title: 'Mudança', dueDate: '2026-09-03'),
        [Subtask(taskId: 0, title: 'Caixas')],
      );
      final task = (await db.getTaskById(taskId))!;
      final caixas = task.subtasks.single;

      await service.updateTask(task, [
        caixas.copyWith(completed: true),
        Subtask(taskId: 0, title: 'Fita'),
      ]);

      final after = (await db.getTaskById(taskId))!;
      expect(after.subtasks.length, 2);
      expect(findSubtask(after, 'Caixas')!.id, caixas.id);
      expect(findSubtask(after, 'Caixas')!.completed, isTrue);
    });
  });

  group('Override de ocorrência', () {
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
        time: '15:00',
        description: 'Academia',
      );
    });

    tearDown(() async {
      await disposeTestTaskService(db: db, dir: dir);
    });

    test('string vazia remove descrição e horário só naquela data', () async {
      await service.updateOccurrence(
        taskId,
        date(2026, 9, 2),
        description: '',
        time: '',
      );

      final wed = (await loadTaskOnDate(service, date(2026, 9, 2), 'Treino'))!;
      expect(wed.effectiveDescription, isEmpty);
      expect(wed.effectiveTime, isNull);

      final fri = (await loadTaskOnDate(service, date(2026, 9, 4), 'Treino'))!;
      expect(fri.effectiveDescription, 'Academia');
      expect(fri.effectiveTime, '15:00');
    });

    test('override sem mudanças não cria linha', () async {
      await service.updateOccurrence(taskId, date(2026, 9, 2));
      expect(await db.getOccurrence(taskId, '2026-09-02'), isNull);
    });
  });
}
