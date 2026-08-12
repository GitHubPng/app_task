import '../database/database_helper.dart';
import '../models/task.dart';
import '../models/subtask.dart';
import '../utils/weekday_utils.dart';

class TaskService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ─── TASKS ───────────────────────────────────────────────

  Future<List<Task>> getAllTasks({
    String? searchQuery,
    int? weekday,
  }) async {
    final day = weekday ?? DateTime.now().weekday;
    final dateStr =
        WeekdayUtils.toDateString(WeekdayUtils.dateForWeekday(day));
    return await _db.getTasks(
      searchQuery: searchQuery,
      completionDate: dateStr,
    );
  }

  /// Lista do dia selecionado (recorrentes + avulsas daquela data).
  Future<List<Task>> getTasksForWeekday(int weekday) async {
    final date = WeekdayUtils.dateForWeekday(weekday);
    final dateStr = WeekdayUtils.toDateString(date);
    return await _db.getTasksForDay(weekday: weekday, dateStr: dateStr);
  }

  Future<List<Task>> getArchivedTasks() async {
    return await _db.getArchivedTasks();
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
    await _db.deleteSubtasksByTask(task.id!);
    for (final sub in subtasks) {
      await _db.insertSubtask(sub.copyWith(taskId: task.id!));
    }
  }

  Future<void> deleteTask(int id) async {
    await _db.deleteTask(id);
  }

  /// Conclusão unificada: avulsa usa tasks.completed (+ arquivo);
  /// recorrente grava em task_completions na data do dia selecionado.
  Future<void> toggleTaskCompleted({
    required Task task,
    required bool completed,
    required int weekday,
  }) async {
    if (task.isRecurring) {
      // RN-NOVA-02 / RN-NOVA-03: não mexe em tasks.completed nem arquiva.
      final dateStr =
          WeekdayUtils.toDateString(WeekdayUtils.dateForWeekday(weekday));
      await _db.setRecurringCompletion(
        taskId: task.id!,
        dateStr: dateStr,
        completed: completed,
      );
    } else {
      // RN-NOVA-04: avulsa arquiva automaticamente ao concluir.
      await _db.toggleOneOffCompleted(task.id!, completed);
    }
  }

  // ─── SUBTASKS ─────────────────────────────────────────────

  Future<void> toggleSubtaskCompleted(int id, bool completed) async {
    await _db.toggleSubtaskCompleted(id, completed);
  }

  Future<void> deleteSubtask(int id) async {
    await _db.deleteSubtask(id);
  }
}
