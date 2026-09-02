import 'dart:io';

import 'package:app_task/database/database_helper.dart';
import 'package:app_task/models/subtask.dart';
import 'package:app_task/models/task.dart';
import 'package:app_task/services/task_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Inicializa sqflite FFI (desktop/CI).
void initTestDatabase() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// Cria banco v3 limpo para testes de serviço.
Future<({TaskService service, DatabaseHelper db, Directory dir})>
    createTestTaskService() async {
  final dir = await Directory.systemTemp.createTemp('app_task_test_');
  final dbPath = '${dir.path}/test.db';
  final db = DatabaseHelper.test(dbPath);
  final service = TaskService(db: db);
  await db.database;
  return (service: service, db: db, dir: dir);
}

Future<void> disposeTestTaskService({
  required DatabaseHelper db,
  required Directory dir,
}) async {
  await db.closeForTest();
  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
}

/// Cria banco equivalente à versão 2 com dados de fixture.
Future<String> createV2DatabaseFixture(Directory dir) async {
  final path = '${dir.path}/migration_v2.db';

  final db = await openDatabase(
    path,
    version: 2,
    onConfigure: (d) async {
      await d.execute('PRAGMA foreign_keys = ON');
    },
    onCreate: (d, version) async {
      await d.execute('''
        CREATE TABLE tasks(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          description TEXT,
          due_date TEXT,
          completed INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          is_recurring INTEGER DEFAULT 0,
          recurring_days TEXT,
          time TEXT,
          archived INTEGER DEFAULT 0
        )
      ''');

      await d.execute('''
        CREATE TABLE subtasks(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          task_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          completed INTEGER DEFAULT 0,
          FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE
        )
      ''');

      await d.execute('''
        CREATE TABLE task_completions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          task_id INTEGER NOT NULL,
          completion_date TEXT NOT NULL,
          completed INTEGER DEFAULT 1,
          FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE,
          UNIQUE(task_id, completion_date)
        )
      ''');
    },
  );

  final recurringId = await db.insert('tasks', {
    'title': 'Treino v2',
    'description': 'rotina',
    'due_date': null,
    'completed': 0,
    'created_at': '2026-01-01T00:00:00.000',
    'is_recurring': 1,
    'recurring_days': '1,3',
    'time': '15:00',
    'archived': 0,
  });

  final oneOffId = await db.insert('tasks', {
    'title': 'Avulsa v2',
    'description': null,
    'due_date': '2026-09-03',
    'completed': 0,
    'created_at': '2026-01-01T00:00:00.000',
    'is_recurring': 0,
    'recurring_days': null,
    'time': null,
    'archived': 0,
  });

  await db.insert('tasks', {
    'title': 'Arquivada v2',
    'description': null,
    'due_date': '2026-08-01',
    'completed': 1,
    'created_at': '2026-01-01T00:00:00.000',
    'is_recurring': 0,
    'recurring_days': null,
    'time': null,
    'archived': 1,
  });

  await db.insert('subtasks', {
    'task_id': recurringId,
    'title': 'Supino',
    'completed': 1,
  });

  await db.insert('subtasks', {
    'task_id': oneOffId,
    'title': 'Etapa avulsa',
    'completed': 1,
  });

  await db.insert('task_completions', {
    'task_id': recurringId,
    'completion_date': '2026-08-31',
    'completed': 1,
  });

  await db.close();
  return path;
}

DateTime date(int y, int m, int d) => DateTime(y, m, d);

Task recurringTask({
  required String title,
  String recurringDays = '1,3,5',
  String? time,
  String? description,
}) {
  return Task(
    title: title,
    description: description,
    createdAt: '2026-01-01T00:00:00.000',
    isRecurring: true,
    recurringDays: recurringDays,
    time: time,
  );
}

Task oneOffTask({
  required String title,
  required String dueDate,
}) {
  return Task(
    title: title,
    createdAt: '2026-01-01T00:00:00.000',
    isRecurring: false,
    dueDate: dueDate,
  );
}

Future<int> createRecurringWithSubtasks(
  TaskService service, {
  required String title,
  String recurringDays = '1,3,5',
  String? time,
  String? description,
  List<String> subtaskTitles = const [],
}) async {
  return service.createTask(
    recurringTask(
      title: title,
      recurringDays: recurringDays,
      time: time,
      description: description,
    ),
    subtaskTitles.map((t) => Subtask(taskId: 0, title: t)).toList(),
  );
}

Task? findByTitle(List<Task> tasks, String title) {
  for (final t in tasks) {
    if (t.effectiveTitle == title || t.title == title) return t;
  }
  return null;
}

bool containsTitle(List<Task> tasks, String title) =>
    findByTitle(tasks, title) != null;

Future<bool> taskAppearsOn(
  TaskService service,
  DateTime day,
  String title,
) async {
  final tasks = await service.getTasksForDate(day);
  return containsTitle(tasks, title);
}

Subtask? findSubtask(Task task, String title) {
  for (final s in task.subtasks) {
    if (s.title == title) return s;
  }
  return null;
}

Future<Task?> loadTaskOnDate(
  TaskService service,
  DateTime day,
  String title,
) async {
  final tasks = await service.getTasksForDate(day);
  return findByTitle(tasks, title);
}
