import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';
import '../models/subtask.dart';
import '../models/task_completion.dart';
import '../utils/weekday_utils.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'apptask.db');

    return await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        // Necessário para ON DELETE CASCADE em subtarefas e completions.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
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

    // Histórico de conclusão por dia — reset diário das recorrentes.
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

    await _seedWeeklyRoutine(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN is_recurring INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE tasks ADD COLUMN recurring_days TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN time TEXT');
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN archived INTEGER DEFAULT 0',
      );
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
      // Seed só na criação do zero; upgrade preserva dados do usuário.
    }
  }

  /// Rotina semanal inicial (editável pelo usuário depois).
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
      await db.insert('tasks', {
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
    }
  }

  // ─── TASKS ───────────────────────────────────────────────

  Future<int> insertTask(Task task) async {
    final db = await database;
    return await db.insert('tasks', task.toMap()..remove('id'));
  }

  /// Lista tarefas ativas (não arquivadas). Busca ignora filtro de dia.
  /// [completionDate] aplica o status "feito neste dia" nas recorrentes.
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

    final tasks = await _hydrateTasks(maps);
    final date = completionDate ?? WeekdayUtils.todayString();
    await _applyCompletionsForDate(tasks, date);
    return tasks;
  }

  /// Tarefas do dia: recorrentes daquele weekday + avulsas com dueDate na data.
  ///
  /// [weekday] 1–7; [dateStr] YYYY-MM-DD daquele dia na semana corrente.
  /// Ordenação cronológica por time (sem horário no fim).
  Future<List<Task>> getTasksForDay({
    required int weekday,
    required String dateStr,
  }) async {
    final db = await database;

    // Recorrentes: recurring_days contém o weekday (ex.: %,3,% ou 3,% ou %,3 ou 3).
    final recurringMaps = await db.query(
      'tasks',
      where: '''
        archived = 0 AND is_recurring = 1 AND (
          recurring_days = ? OR
          recurring_days LIKE ? OR
          recurring_days LIKE ? OR
          recurring_days LIKE ?
        )
      ''',
      whereArgs: [
        '$weekday',
        '$weekday,%',
        '%,$weekday',
        '%,$weekday,%',
      ],
    );

    // Avulsas com data naquele dia; sem data aparecem só no "hoje".
    final isToday = dateStr == WeekdayUtils.todayString();
    final oneOffMaps = await db.query(
      'tasks',
      where: isToday
          ? 'archived = 0 AND is_recurring = 0 AND (due_date = ? OR due_date IS NULL)'
          : 'archived = 0 AND is_recurring = 0 AND due_date = ?',
      whereArgs: [dateStr],
    );

    final maps = [...recurringMaps, ...oneOffMaps];
    final tasks = await _hydrateTasks(maps);

    // Marca completed das recorrentes conforme task_completions daquela data.
    await _applyCompletionsForDate(tasks, dateStr);

    tasks.sort(_compareByTimeThenCreated);
    return tasks;
  }

  Future<List<Task>> getArchivedTasks() async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'archived = 1',
      orderBy: 'created_at DESC',
    );
    return _hydrateTasks(maps);
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
    // CASCADE remove subtarefas e task_completions (RN-NOVA-06).
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  /// Conclusão de tarefa avulsa: atualiza completed e arquiva ao concluir (RN-NOVA-04).
  Future<int> toggleOneOffCompleted(int id, bool completed) async {
    final db = await database;
    return await db.update(
      'tasks',
      {
        'completed': completed ? 1 : 0,
        // Só arquiva ao marcar concluída; se desmarcar (ainda na lista), desarquiva.
        'archived': completed ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── TASK COMPLETIONS (recorrentes) ───────────────────────

  /// Marca/desmarca conclusão da recorrente na data (RN-NOVA-02).
  /// Não altera o campo completed da tabela tasks.
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

  Future<int> deleteSubtask(int id) async {
    final db = await database;
    return await db.delete('subtasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSubtasksByTask(int taskId) async {
    final db = await database;
    await db.delete('subtasks', where: 'task_id = ?', whereArgs: [taskId]);
  }

  // ─── helpers internos ─────────────────────────────────────

  Future<List<Task>> _hydrateTasks(List<Map<String, dynamic>> maps) async {
    final tasks = <Task>[];
    for (final map in maps) {
      final task = Task.fromMap(map);
      task.subtasks = await getSubtasks(task.id!);
      tasks.add(task);
    }
    return tasks;
  }

  /// Aplica completed "virtual" nas recorrentes a partir de task_completions.
  Future<void> _applyCompletionsForDate(
    List<Task> tasks,
    String dateStr,
  ) async {
    for (final task in tasks) {
      if (task.isRecurring && task.id != null) {
        task.completed = await isRecurringCompletedOn(task.id!, dateStr);
      }
    }
  }

  int _compareByTimeThenCreated(Task a, Task b) {
    final aHas = a.time != null && a.time!.isNotEmpty;
    final bHas = b.time != null && b.time!.isNotEmpty;
    if (aHas && bHas) {
      final cmp = a.time!.compareTo(b.time!);
      if (cmp != 0) return cmp;
    } else if (aHas && !bHas) {
      return -1;
    } else if (!aHas && bHas) {
      return 1;
    }
    // Pendentes primeiro, depois mais recentes.
    if (a.completed != b.completed) {
      return a.completed ? 1 : -1;
    }
    return b.createdAt.compareTo(a.createdAt);
  }
}
