import '../database/database_helper.dart';
import '../models/task.dart';
import '../models/subtask.dart';

class TaskService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ─── TASKS ───────────────────────────────────────────────

  Future<List<Task>> getAllTasks({String? searchQuery}) async {
    return await _db.getTasks(searchQuery: searchQuery);
  }

  Future<Task?> getTaskById(int id) async {
    return await _db.getTaskById(id);
  }

  /// Returns the new task id
  Future<int> createTask(Task task, List<Subtask> subtasks) async {
    final taskId = await _db.insertTask(task);
    for (final sub in subtasks) {
      await _db.insertSubtask(sub.copyWith(taskId: taskId));
    }
    return taskId;
  }

  /// Full update: replaces task fields + subtask list
  Future<void> updateTask(Task task, List<Subtask> subtasks) async {
    await _db.updateTask(task);
    // Remove all old subtasks and re-insert the current list
    await _db.deleteSubtasksByTask(task.id!);
    for (final sub in subtasks) {
      await _db.insertSubtask(sub.copyWith(taskId: task.id!));
    }
  }

  Future<void> deleteTask(int id) async {
    await _db.deleteTask(id);
  }

  Future<void> toggleTaskCompleted(int id, bool completed) async {
    await _db.toggleTaskCompleted(id, completed);
  }

  // ─── SUBTASKS ─────────────────────────────────────────────

  Future<void> toggleSubtaskCompleted(int id, bool completed) async {
    await _db.toggleSubtaskCompleted(id, completed);
  }

  Future<void> deleteSubtask(int id) async {
    await _db.deleteSubtask(id);
  }
}
