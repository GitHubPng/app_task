import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';
import '../models/subtask.dart';
import '../models/task_completion.dart';
import '../models/task_occurrence.dart';
import '../models/subtask_completion.dart';
import '../models/task_recurrence_rule.dart';
import '../utils/weekday_utils.dart';

/// Data usada na migração para cobrir todo histórico existente.
const kLegacyRuleEffectiveFrom = '1970-01-01';

class DatabaseHelper {
  static DatabaseHelper instance = DatabaseHelper._internal();

  Database? _database;
  String? _testDbPath;
  bool _skipSeed = false;

  DatabaseHelper._internal();

  /// Banco em memória/arquivo isolado para testes (sem seed da rotina).
  @visibleForTesting
  DatabaseHelper.test(String dbPath, {bool skipSeed = true})
      : _testDbPath = dbPath,
        _skipSeed = skipSeed;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = _testDbPath ?? join(await getDatabasesPath(), 'apptask.db');

    return await openDatabase(
      path,
      version: 4,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createCoreTables(db);
    await _createOccurrenceTables(db);
    await _createRecurrenceRulesTable(db);
    if (!_skipSeed) {
      await _seedWeeklyRoutine(db);
    }
  }

  Future<void> _createCoreTables(Database db) async {
    await db.execute('''
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

    await db.execute('''
      CREATE TABLE subtasks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        completed INTEGER DEFAULT 0,
        FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE task_completions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        completion_date TEXT NOT NULL,
        completed INTEGER DEFAULT 1,
        FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE,
        UNIQUE(task_id, completion_date)
      )
    ''');
  }

  Future<void> _createOccurrenceTables(Database db) async {
    await db.execute('''
      CREATE TABLE task_occurrences(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        occurrence_date TEXT NOT NULL,
        title TEXT,
        description TEXT,
        time TEXT,
        cancelled INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE,
        UNIQUE(task_id, occurrence_date)
      )
    ''');

    await db.execute('''
      CREATE TABLE subtask_completions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subtask_id INTEGER NOT NULL,
        occurrence_date TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY(subtask_id) REFERENCES subtasks(id) ON DELETE CASCADE,
        UNIQUE(subtask_id, occurrence_date)
      )
    ''');
  }

  Future<void> _createRecurrenceRulesTable(Database db) async {
    await db.execute('''
      CREATE TABLE task_recurrence_rules(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        effective_from TEXT NOT NULL,
        recurring_days TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        time TEXT,
        FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE,
        UNIQUE(task_id, effective_from)
      )
    ''');
  }

  /// Expõe migração para testes de upgrade v2 → v3.
  @visibleForTesting
  Future<void> runUpgrade(Database db, int oldVersion, int newVersion) =>
      _onUpgrade(db, oldVersion, newVersion);

  @visibleForTesting
  Future<void> closeForTest() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _addColumnIfMissing(
        db,
        'tasks',
        'is_recurring',
        'INTEGER DEFAULT 0',
      );
      await _addColumnIfMissing(db, 'tasks', 'recurring_days', 'TEXT');
      await _addColumnIfMissing(db, 'tasks', 'time', 'TEXT');
      await _addColumnIfMissing(db, 'tasks', 'archived', 'INTEGER DEFAULT 0');

      if (!await _tableExists(db, 'task_completions')) {
        await db.execute('''
          CREATE TABLE task_completions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            task_id INTEGER NOT NULL,
            completion_date TEXT NOT NULL,
            completed INTEGER DEFAULT 1,
            FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE,
            UNIQUE(task_id, completion_date)
          )
        ''');
      }
    }

    if (oldVersion < 3) {
      if (!await _tableExists(db, 'task_occurrences')) {
        await db.execute('''
          CREATE TABLE task_occurrences(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            task_id INTEGER NOT NULL,
            occurrence_date TEXT NOT NULL,
            title TEXT,
            description TEXT,
            time TEXT,
            cancelled INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE,
            UNIQUE(task_id, occurrence_date)
          )
        ''');
      }

      if (!await _tableExists(db, 'subtask_completions')) {
        await db.execute('''
          CREATE TABLE subtask_completions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subtask_id INTEGER NOT NULL,
            occurrence_date TEXT NOT NULL,
            completed INTEGER NOT NULL DEFAULT 1,
            FOREIGN KEY(subtask_id) REFERENCES subtasks(id) ON DELETE CASCADE,
            UNIQUE(subtask_id, occurrence_date)
          )
        ''');
      }

      // Subtarefas de rotinas: completed era global — reset sem inventar data.
      await db.execute('''
        UPDATE subtasks
        SET completed = 0
        WHERE task_id IN (
          SELECT id FROM tasks WHERE is_recurring = 1
        )
      ''');
    }

    if (oldVersion < 4) {
      if (!await _tableExists(db, 'task_recurrence_rules')) {
        await _createRecurrenceRulesTable(db);
      }

      final recurringTasks = await db.query(
        'tasks',
        where: 'is_recurring = 1',
      );
      for (final row in recurringTasks) {
        final taskId = row['id'] as int;
        final existing = await db.query(
          'task_recurrence_rules',
          where: 'task_id = ?',
          whereArgs: [taskId],
          limit: 1,
        );
        if (existing.isNotEmpty) continue;

        await db.insert('task_recurrence_rules', {
          'task_id': taskId,
          'effective_from': kLegacyRuleEffectiveFrom,
          'recurring_days': row['recurring_days'] ?? '',
          'title': row['title'],
          'description': row['description'],
          'time': row['time'],
        });
      }
    }
  }

  Future<bool> _tableExists(Database db, String table) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [table],
    );
    return rows.isNotEmpty;
  }

  Future<bool> _columnExists(Database db, String table, String column) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return info.any((row) => row['name'] == column);
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    if (await _columnExists(db, table, column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<void> _seedWeeklyRoutine(Database db) async {
    final now = DateTime.now().toIso8601String();

    final seeds = <Map<String, dynamic>>[
      {'title': 'Acordar', 'days': '1,2,3,4,5', 'time': '05:50'},
      {'title': 'Banho e se vestir', 'days': '1,2,3,4,5', 'time': '06:00'},
      {'title': 'Café da manhã', 'days': '1,2,3,4,5', 'time': '06:10'},
      {
        'title': 'Deslocamento para o trabalho',
        'days': '1,2,3,4,5',
        'time': '07:00',
      },
      {'title': 'Trabalho', 'days': '1,2,3,4,5', 'time': '08:00'},
      {'title': 'Curso técnico', 'days': '2,4', 'time': '14:00'},
      {'title': 'Treino', 'days': '1,3', 'time': '15:00'},
      {
        'title': 'Consulta psicológica (online)',
        'days': '5',
        'time': '15:30',
      },
      {'title': 'Escola', 'days': '1,2,3,4,5', 'time': '19:00'},
      {'title': 'Dormir', 'days': '1,2,3,4,5', 'time': '22:30'},
    ];

    for (final seed in seeds) {
      final taskId = await db.insert('tasks', {
        'title': seed['title'],
        'description': null,
        'due_date': null,
        'completed': 0,
        'created_at': now,
        'is_recurring': 1,
        'recurring_days': seed['days'],
        'time': seed['time'],
        'archived': 0,
      });
      await db.insert('task_recurrence_rules', {
        'task_id': taskId,
        'effective_from': kLegacyRuleEffectiveFrom,
        'recurring_days': seed['days'],
        'title': seed['title'],
        'description': null,
        'time': seed['time'],
      });
    }
  }

  // ─── TASKS ───────────────────────────────────────────────

  Future<int> insertTask(Task task) async {
    final db = await database;
    return await db.insert('tasks', task.toMap()..remove('id'));
  }

  Future<List<Task>> getTasks({
    String? searchQuery,
    String? completionDate,
  }) async {
    final db = await database;

    List<Map<String, dynamic>> maps;

    if (searchQuery != null && searchQuery.isNotEmpty) {
      maps = await db.query(
        'tasks',
        where: 'archived = 0 AND title LIKE ?',
        whereArgs: ['%$searchQuery%'],
        orderBy: 'completed ASC, created_at DESC',
      );
    } else {
      maps = await db.query(
        'tasks',
        where: 'archived = 0',
        orderBy: 'completed ASC, created_at DESC',
      );
    }

    final date = completionDate ?? WeekdayUtils.todayString();
    return _hydrateTasksForDate(maps, date, isRecurring: null);
  }

  /// Tarefas de uma data concreta: recorrentes (virtuais + overrides) + avulsas.
  Future<List<Task>> getTasksForDate({
    required int weekday,
    required String dateStr,
  }) async {
    final db = await database;

    final recurringMaps = await db.query(
      'tasks',
      where: 'archived = 0 AND is_recurring = 1',
    );

    final oneOffMaps = await db.query(
      'tasks',
      where: 'archived = 0 AND is_recurring = 0 AND due_date = ?',
      whereArgs: [dateStr],
    );

    final recurringTasks = await _hydrateRecurringTasksForDate(
      recurringMaps,
      dateStr,
      weekday,
    );

    final oneOffTasks = await _hydrateTasksForDate(oneOffMaps, dateStr);
    final tasks = [...recurringTasks, ...oneOffTasks];

    tasks.sort(_compareByEffectiveTimeThenCreated);
    return tasks;
  }

  Future<List<Task>> getArchivedTasks() async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'archived = 1',
      orderBy: 'created_at DESC',
    );
    return _hydrateTasksForDate(maps, WeekdayUtils.todayString());
  }

  Future<Task?> getTaskById(int id) async {
    final db = await database;
    final maps = await db.query('tasks', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    final task = Task.fromMap(maps.first);
    task.subtasks = await getSubtasks(id);
    return task;
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    final map = task.toMap()..remove('id');
    return await db.update(
      'tasks',
      map,
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  /// Conclusão de tarefa avulsa: atualiza completed sem arquivar automaticamente.
  Future<int> toggleOneOffCompleted(int id, bool completed) async {
    final db = await database;
    return await db.update(
      'tasks',
      {'completed': completed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── TASK RECURRENCE RULES ────────────────────────────────

  Future<TaskRecurrenceRule?> getRecurrenceRuleForDate(
    int taskId,
    String dateStr,
  ) async {
    final db = await database;
    final maps = await db.query(
      'task_recurrence_rules',
      where: 'task_id = ? AND effective_from <= ?',
      whereArgs: [taskId, dateStr],
      orderBy: 'effective_from DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TaskRecurrenceRule.fromMap(maps.first);
  }

  /// UPSERT de versão da regra a partir de [effectiveFrom].
  Future<void> upsertRecurrenceRule({
    required int taskId,
    required String effectiveFrom,
    required String recurringDays,
    required String title,
    String? description,
    String? time,
  }) async {
    final db = await database;
    final existing = await db.query(
      'task_recurrence_rules',
      where: 'task_id = ? AND effective_from = ?',
      whereArgs: [taskId, effectiveFrom],
      limit: 1,
    );

    final payload = {
      'recurring_days': recurringDays,
      'title': title,
      'description': description,
      'time': time,
    };

    if (existing.isNotEmpty) {
      await db.update(
        'task_recurrence_rules',
        payload,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert(
        'task_recurrence_rules',
        {
          'task_id': taskId,
          'effective_from': effectiveFrom,
          ...payload,
        },
      );
    }
  }

  /// Garante aparição na data (ex.: conversão de avulsa com due_date fora dos dias).
  Future<void> ensureOccurrenceAnchor({
    required int taskId,
    required String dateStr,
  }) async {
    final existing = await getOccurrence(taskId, dateStr);
    if (existing != null) return;

    final db = await database;
    await db.insert(
      'task_occurrences',
      TaskOccurrence(
        taskId: taskId,
        occurrenceDate: dateStr,
      ).toMap()
        ..remove('id'),
    );
  }

  // ─── TASK OCCURRENCES ─────────────────────────────────────

  Future<TaskOccurrence?> getOccurrence(int taskId, String dateStr) async {
    final db = await database;
    final maps = await db.query(
      'task_occurrences',
      where: 'task_id = ? AND occurrence_date = ?',
      whereArgs: [taskId, dateStr],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TaskOccurrence.fromMap(maps.first);
  }

  /// UPSERT de override pontual — não altera tasks.
  Future<void> upsertOccurrence({
    required int taskId,
    required String dateStr,
    String? title,
    String? description,
    String? time,
  }) async {
    final db = await database;
    final existing = await getOccurrence(taskId, dateStr);

    if (existing != null) {
      await db.update(
        'task_occurrences',
        {
          'title': title,
          'description': description,
          'time': time,
          'cancelled': 0,
        },
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    } else {
      await db.insert(
        'task_occurrences',
        TaskOccurrence(
          taskId: taskId,
          occurrenceDate: dateStr,
          title: title,
          description: description,
          time: time,
        ).toMap()
          ..remove('id'),
      );
    }
  }

  /// Cancela somente a ocorrência na data (regra permanece em tasks).
  Future<void> cancelOccurrence({
    required int taskId,
    required String dateStr,
  }) async {
    final db = await database;
    final existing = await getOccurrence(taskId, dateStr);

    if (existing != null) {
      await db.update(
        'task_occurrences',
        {'cancelled': 1},
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    } else {
      await db.insert(
        'task_occurrences',
        TaskOccurrence(
          taskId: taskId,
          occurrenceDate: dateStr,
          cancelled: true,
        ).toMap()
          ..remove('id'),
      );
    }
  }

  // ─── TASK COMPLETIONS (recorrentes) ───────────────────────

  Future<void> setRecurringCompletion({
    required int taskId,
    required String dateStr,
    required bool completed,
  }) async {
    final db = await database;

    if (completed) {
      await db.insert(
        'task_completions',
        TaskCompletion(
          taskId: taskId,
          completionDate: dateStr,
          completed: true,
        ).toMap()
          ..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await db.delete(
        'task_completions',
        where: 'task_id = ? AND completion_date = ?',
        whereArgs: [taskId, dateStr],
      );
    }
  }

  Future<bool> isRecurringCompletedOn(int taskId, String dateStr) async {
    final db = await database;
    final maps = await db.query(
      'task_completions',
      where: 'task_id = ? AND completion_date = ? AND completed = 1',
      whereArgs: [taskId, dateStr],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  // ─── SUBTASKS ─────────────────────────────────────────────

  Future<int> insertSubtask(Subtask subtask) async {
    final db = await database;
    return await db.insert('subtasks', subtask.toMap()..remove('id'));
  }

  Future<List<Subtask>> getSubtasks(int taskId) async {
    final db = await database;
    final maps = await db.query(
      'subtasks',
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
    return maps.map((m) => Subtask.fromMap(m)).toList();
  }

  Future<int> updateSubtask(Subtask subtask) async {
    final db = await database;
    return await db.update(
      'subtasks',
      subtask.toMap(),
      where: 'id = ?',
      whereArgs: [subtask.id],
    );
  }

  Future<int> toggleSubtaskCompleted(int id, bool completed) async {
    final db = await database;
    return await db.update(
      'subtasks',
      {'completed': completed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setSubtaskCompletionForDate({
    required int subtaskId,
    required String dateStr,
    required bool completed,
  }) async {
    final db = await database;

    if (completed) {
      await db.insert(
        'subtask_completions',
        SubtaskCompletion(
          subtaskId: subtaskId,
          occurrenceDate: dateStr,
          completed: true,
        ).toMap()
          ..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await db.delete(
        'subtask_completions',
        where: 'subtask_id = ? AND occurrence_date = ?',
        whereArgs: [subtaskId, dateStr],
      );
    }
  }

  Future<bool> isSubtaskCompletedOn(int subtaskId, String dateStr) async {
    final db = await database;
    final maps = await db.query(
      'subtask_completions',
      where: 'subtask_id = ? AND occurrence_date = ? AND completed = 1',
      whereArgs: [subtaskId, dateStr],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  Future<int> deleteSubtask(int id) async {
    final db = await database;
    return await db.delete('subtasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSubtasksByTask(int taskId) async {
    final db = await database;
    await db.delete('subtasks', where: 'task_id = ?', whereArgs: [taskId]);
  }

  // ─── helpers internos ─────────────────────────────────────

  Future<List<Task>> _hydrateRecurringTasksForDate(
    List<Map<String, dynamic>> maps,
    String dateStr,
    int weekday,
  ) async {
    final tasks = <Task>[];
    for (final map in maps) {
      final taskId = map['id'] as int;
      final rule = await getRecurrenceRuleForDate(taskId, dateStr);
      if (rule == null) continue;

      final occurrence = await getOccurrence(taskId, dateStr);
      if (occurrence?.cancelled == true) continue;

      final inRule = rule.recurringDaysList.contains(weekday);
      final hasAnchor = occurrence != null && !inRule;
      if (!inRule && !hasAnchor) continue;

      final task = Task.fromMap(map);
      task.occurrenceDate = dateStr;
      _applyRuleToTask(task, rule);
      await _applyOccurrenceAndCompletions(task, dateStr, occurrence);
      tasks.add(task);
    }
    return tasks;
  }

  void _applyRuleToTask(Task task, TaskRecurrenceRule rule) {
    task.ruleTitleForDate = rule.title;
    task.ruleDescriptionForDate = rule.description;
    task.ruleTimeForDate = rule.time;
    task.ruleRecurringDaysForDate = rule.recurringDays;
  }

  Future<void> _applyOccurrenceAndCompletions(
    Task task,
    String dateStr,
    TaskOccurrence? occurrence,
  ) async {
    if (occurrence != null) {
      task.occurrenceId = occurrence.id;
      if (occurrence.title != null) {
        task.occurrenceTitleOverride = occurrence.title;
      }
      if (occurrence.description != null) {
        task.occurrenceDescriptionOverride = occurrence.description;
      }
      if (occurrence.time != null) {
        task.occurrenceTimeOverride = occurrence.time;
      }
      task.isOccurrenceOverride = occurrence.title != null ||
          occurrence.description != null ||
          occurrence.time != null;
    }

    task.completed = await isRecurringCompletedOn(task.id!, dateStr);
    task.subtasks = await getSubtasks(task.id!);
    for (final sub in task.subtasks) {
      sub.completed = await isSubtaskCompletedOn(sub.id!, dateStr);
    }
  }

  Future<List<Task>> _hydrateTasksForDate(
    List<Map<String, dynamic>> maps,
    String dateStr, {
    bool? isRecurring,
  }) async {
    final tasks = <Task>[];
    for (final map in maps) {
      final task = Task.fromMap(map);
      task.occurrenceDate = dateStr;

      if (task.isRecurring) {
        final rule = await getRecurrenceRuleForDate(task.id!, dateStr);
        if (rule != null) {
          _applyRuleToTask(task, rule);
        }
        final occurrence = await getOccurrence(task.id!, dateStr);
        if (occurrence?.cancelled == true) continue;
        await _applyOccurrenceAndCompletions(task, dateStr, occurrence);
      } else {
        task.subtasks = await getSubtasks(task.id!);
      }

      if (isRecurring != null && task.isRecurring != isRecurring) continue;
      tasks.add(task);
    }
    return tasks;
  }

  int _compareByEffectiveTimeThenCreated(Task a, Task b) {
    final aTime = a.effectiveTime;
    final bTime = b.effectiveTime;
    final aHas = aTime != null && aTime.isNotEmpty;
    final bHas = bTime != null && bTime.isNotEmpty;
    if (aHas && bHas) {
      final cmp = aTime.compareTo(bTime);
      if (cmp != 0) return cmp;
    } else if (aHas && !bHas) {
      return -1;
    } else if (!aHas && bHas) {
      return 1;
    }
    if (a.completed != b.completed) {
      return a.completed ? 1 : -1;
    }
    return b.createdAt.compareTo(a.createdAt);
  }
}
