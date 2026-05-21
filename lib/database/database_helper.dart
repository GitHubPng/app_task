import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';
import '../models/subtask.dart';

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
      version: 1,
      onCreate: _onCreate,
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
        created_at TEXT NOT NULL
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
  }

  // ─── TASKS ───────────────────────────────────────────────

  Future<int> insertTask(Task task) async {
    final db = await database;
    return await db.insert('tasks', task.toMap());
  }

  Future<List<Task>> getTasks({String? searchQuery}) async {
    final db = await database;

    List<Map<String, dynamic>> maps;

    if (searchQuery != null && searchQuery.isNotEmpty) {
      maps = await db.query(
        'tasks',
        where: 'title LIKE ?',
        whereArgs: ['%$searchQuery%'],
        orderBy: 'completed ASC, created_at DESC',
      );
    } else {
      maps = await db.query(
        'tasks',
        orderBy: 'completed ASC, created_at DESC',
      );
    }

    final tasks = <Task>[];
    for (final map in maps) {
      final task = Task.fromMap(map);
      task.subtasks = await getSubtasks(task.id!);
      tasks.add(task);
    }
    return tasks;
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
    return await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    // ON DELETE CASCADE handles subtasks automatically
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> toggleTaskCompleted(int id, bool completed) async {
    final db = await database;
    return await db.update(
      'tasks',
      {'completed': completed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── SUBTASKS ─────────────────────────────────────────────

  Future<int> insertSubtask(Subtask subtask) async {
    final db = await database;
    return await db.insert('subtasks', subtask.toMap());
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
}
