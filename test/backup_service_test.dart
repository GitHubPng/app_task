import 'dart:convert';
import 'dart:io';

import 'package:app_task/database/database_helper.dart';
import 'package:app_task/models/task.dart';
import 'package:app_task/services/backup_service.dart';
import 'package:app_task/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

void main() {
  setUpAll(() {
    initTestDatabase();
  });

  late Directory dir;
  late DatabaseHelper source;
  late DatabaseHelper target;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('app_task_backup_');
    source = DatabaseHelper.test('${dir.path}/source.db');
    target = DatabaseHelper.test('${dir.path}/target.db');
  });

  tearDown(() async {
    await source.closeForTest();
    await target.closeForTest();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<Map<String, List<Map<String, Object?>>>> dump(
    DatabaseHelper helper,
  ) async {
    final db = await helper.database;
    return {
      for (final table in BackupService.tables)
        table: (await db.query(table, orderBy: 'id'))
            .map((r) => Map<String, Object?>.from(r)..remove('archived'))
            .toList(),
    };
  }

  Future<void> seed(TaskService service) async {
    final treinoId = await createRecurringWithSubtasks(
      service,
      title: 'Treino',
      time: '15:00',
      subtaskTitles: ['Supino', 'Remada'],
    );
    final mon = (await loadTaskOnDate(service, date(2026, 8, 31), 'Treino'))!;
    await service.toggleTaskCompleted(
      task: mon,
      completed: true,
      date: date(2026, 8, 31),
    );
    await service.toggleSubtaskCompleted(
      findSubtask(mon, 'Supino')!.id!,
      date(2026, 8, 31),
      true,
      isRecurring: true,
    );
    await service.updateOccurrence(treinoId, date(2026, 9, 2), time: '18:00');
    await service.cancelOccurrence(treinoId, date(2026, 9, 4));
    await service.updateRecurrenceRule(
      taskId: treinoId,
      effectiveFrom: date(2026, 9, 7),
      recurringDays: '2,4',
      title: 'Treino',
      time: '07:00',
    );
    await service.createTask(
      oneOffTask(title: 'Dentista', dueDate: '2026-09-03'),
      [],
    );
  }

  test('exportar e importar reproduz o banco inteiro', () async {
    await seed(TaskService(db: source));
    final json = await BackupService(db: source).exportToJson();

    final count = await BackupService(db: target).importFromJson(json);

    expect(count, 2);
    expect(await dump(target), await dump(source));

    final service = TaskService(db: target);
    final mon = (await loadTaskOnDate(service, date(2026, 8, 31), 'Treino'))!;
    expect(mon.completed, isTrue);
    expect(findSubtask(mon, 'Supino')!.completed, isTrue);
    expect(
      (await loadTaskOnDate(service, date(2026, 9, 2), 'Treino'))!
          .effectiveTime,
      '18:00',
    );
    expect(await taskAppearsOn(service, date(2026, 9, 4), 'Treino'), isFalse);
    expect(await taskAppearsOn(service, date(2026, 9, 8), 'Treino'), isTrue);
  });

  test('importar substitui as tarefas existentes', () async {
    await seed(TaskService(db: source));
    final json = await BackupService(db: source).exportToJson();

    final targetService = TaskService(db: target);
    await targetService.createTask(
      oneOffTask(title: 'Vai sumir', dueDate: '2026-09-03'),
      [],
    );

    await BackupService(db: target).importFromJson(json);

    final day = await targetService.getTasksForDate(date(2026, 9, 3));
    expect(containsTitle(day, 'Vai sumir'), isFalse);
    expect(containsTitle(day, 'Dentista'), isTrue);
  });

  test('backup de instalação migrada importa em instalação nova', () async {
    final legacy = DatabaseHelper.test(await createV2DatabaseFixture(dir));
    try {
      final json = await BackupService(db: legacy).exportToJson();
      expect(json.contains('"archived"'), isFalse);

      await BackupService(db: target).importFromJson(json);
      final service = TaskService(db: target);
      expect(
        await taskAppearsOn(service, date(2026, 9, 3), 'Avulsa v2'),
        isTrue,
      );
    } finally {
      await legacy.closeForTest();
    }
  });

  group('versões do backup', () {
    Future<Map<String, dynamic>> exportWithRange() async {
      await TaskService(db: source).createTask(
        Task(
          title: 'Trabalho',
          createdAt: '2026-01-01T00:00:00.000',
          isRecurring: true,
          recurringDays: '1,2,3,4,5',
          time: '08:00',
          endTime: '15:00',
          breakStart: '12:00',
          breakEnd: '13:00',
          reminderEnabled: true,
          reminderMinutesBefore: 30,
        ),
        [],
      );
      return jsonDecode(await BackupService(db: source).exportToJson())
          as Map<String, dynamic>;
    }

    test('roundtrip preserva fim, pausa e lembrete', () async {
      final map = await exportWithRange();
      expect(map['dbVersion'], 7);
      await BackupService(db: target).importFromJson(jsonEncode(map));

      final trabalho = (await loadTaskOnDate(
        TaskService(db: target),
        date(2026, 8, 31),
        'Trabalho',
      ))!;
      expect(trabalho.effectiveEndTime, '15:00');
      expect(trabalho.effectiveBreakStart, '12:00');
      expect(trabalho.effectiveBreakEnd, '13:00');
      expect(trabalho.reminderEnabled, isTrue);
      expect(trabalho.reminderMinutesBefore, 30);
    });

    test('backup v6 (sem colunas de lembrete) importa desligado', () async {
      final map = await exportWithRange();
      map['dbVersion'] = 6;
      for (final row
          in (map['data'] as Map<String, dynamic>)['tasks'] as List) {
        (row as Map<String, dynamic>)
          ..remove('reminder_enabled')
          ..remove('reminder_minutes_before');
      }
      await BackupService(db: target).importFromJson(jsonEncode(map));
      final trabalho = (await loadTaskOnDate(
        TaskService(db: target),
        date(2026, 8, 31),
        'Trabalho',
      ))!;
      expect(trabalho.reminderEnabled, isFalse);
      expect(trabalho.reminderMinutesBefore, isNull);
    });

    test('backup v5 (sem colunas de intervalo) importa', () async {
      final map = await exportWithRange();
      map['dbVersion'] = 5;
      for (final rows in (map['data'] as Map<String, dynamic>).values) {
        for (final row in rows as List) {
          (row as Map<String, dynamic>)
            ..remove('end_time')
            ..remove('break_start')
            ..remove('break_end');
        }
      }

      expect(
        await BackupService(db: target).importFromJson(jsonEncode(map)),
        1,
      );
      final trabalho = (await loadTaskOnDate(
        TaskService(db: target),
        date(2026, 8, 31),
        'Trabalho',
      ))!;
      expect(trabalho.effectiveTime, '08:00');
      expect(trabalho.effectiveEndTime, isNull);
    });

    for (final version in [4, 8]) {
      test('dbVersion $version é recusado', () async {
        final map = await exportWithRange();
        map['dbVersion'] = version;
        await expectLater(
          BackupService(db: target).importFromJson(jsonEncode(map)),
          throwsA(isA<BackupFormatException>()),
        );
      });
    }
  });

  group('arquivo inválido não altera nada', () {
    late TaskService service;

    setUp(() async {
      service = TaskService(db: target);
      await service.createTask(
        oneOffTask(title: 'Intacta', dueDate: '2026-09-03'),
        [],
      );
    });

    Future<void> expectRejected(String json) async {
      await expectLater(
        BackupService(db: target).importFromJson(json),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        await taskAppearsOn(service, date(2026, 9, 3), 'Intacta'),
        isTrue,
      );
    }

    test('não é JSON', () => expectRejected('isso não é json'));

    test('JSON de outro app', () => expectRejected('{"app": "outro"}'));

    test('versão de banco diferente', () async {
      await seed(TaskService(db: source));
      final map = jsonDecode(await BackupService(db: source).exportToJson())
          as Map<String, dynamic>;
      map['dbVersion'] = 99;
      await expectRejected(jsonEncode(map));
    });

    test('subtarefa apontando para tarefa inexistente', () async {
      await seed(TaskService(db: source));
      final map = jsonDecode(await BackupService(db: source).exportToJson())
          as Map<String, dynamic>;
      final subtasks =
          (map['data'] as Map<String, dynamic>)['subtasks'] as List;
      (subtasks.first as Map<String, dynamic>)['task_id'] = 999;
      await expectRejected(jsonEncode(map));
    });
  });
}
