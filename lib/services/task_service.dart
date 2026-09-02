import '../database/database_helper.dart';
import '../models/task.dart';
import '../models/subtask.dart';
import '../utils/weekday_utils.dart';

class TaskService {
  final DatabaseHelper _db;

  TaskService({DatabaseHelper? db}) : _db = db ?? DatabaseHelper.instance;

  // ─── TASKS ───────────────────────────────────────────────

  Future<List<Task>> getAllTasks({
    String? searchQuery,
    DateTime? date,
  }) async {
    final selectedDate = date ?? DateTime.now();
    final dateStr = WeekdayUtils.toDateString(selectedDate);
    return await _db.getTasks(
      searchQuery: searchQuery,
      completionDate: dateStr,
    );
  }

  /// Lista do dia selecionado (recorrentes + avulsas daquela data).
  Future<List<Task>> getTasksForDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final dateStr = WeekdayUtils.toDateString(normalized);
    return await _db.getTasksForDate(
      weekday: normalized.weekday,
      dateStr: dateStr,
    );
  }

  /// Lista de um dia dentro da semana, ou todos os dias se [weekday] for nulo.
  Future<List<Task>> getTasksForWeek(
    DateTime weekStart, {
    int? weekday,
  }) async {
    if (weekday != null) {
      return getTasksForDate(WeekdayUtils.dateInWeek(weekStart, weekday));
    }

    final all = <Task>[];
    for (var day = 1; day <= 7; day++) {
      all.addAll(await getTasksForDate(WeekdayUtils.dateInWeek(weekStart, day)));
    }
    return all;
  }

  /// Compatibilidade interna — preferir [getTasksForDate].
  Future<List<Task>> getTasksForWeekday(int weekday, {DateTime? weekStart}) {
    final ref = weekStart ?? WeekdayUtils.weekStart(DateTime.now());
    return getTasksForDate(WeekdayUtils.dateInWeek(ref, weekday));
  }

  Future<List<Task>> getArchivedTasks() async {
    return await _db.getArchivedTasks();
  }

  Future<Task?> getTaskById(int id) async {
    return await _db.getTaskById(id);
  }

  Future<int> createTask(Task task, List<Subtask> subtasks) async {
    final taskId = await _db.insertTask(task);
    for (final sub in subtasks) {
      await _db.insertSubtask(sub.copyWith(taskId: taskId));
    }
    return taskId;
  }

  Future<void> updateTask(Task task, List<Subtask> subtasks) async {
    await _db.updateTask(task);
    await _db.deleteSubtasksByTask(task.id!);
    for (final sub in subtasks) {
      await _db.insertSubtask(sub.copyWith(taskId: task.id!));
    }
  }

  /// Override pontual de uma ocorrência recorrente — não altera a regra em tasks.
  Future<void> updateOccurrence(
    int taskId,
    DateTime date, {
    String? title,
    String? description,
    String? time,
  }) async {
    final dateStr = WeekdayUtils.toDateString(date);
    await _db.upsertOccurrence(
      taskId: taskId,
      dateStr: dateStr,
      title: title,
      description: description,
      time: time,
    );
  }

  Future<void> deleteTask(int id) async {
    await _db.deleteTask(id);
  }

  /// Cancela somente a ocorrência recorrente na data informada.
  Future<void> cancelOccurrence(int taskId, DateTime date) async {
    final dateStr = WeekdayUtils.toDateString(date);
    await _db.cancelOccurrence(taskId: taskId, dateStr: dateStr);
  }

  /// Conclusão unificada por data concreta.
  Future<void> toggleTaskCompleted({
    required Task task,
    required bool completed,
    required DateTime date,
  }) async {
    if (task.isRecurring) {
      final dateStr = WeekdayUtils.toDateString(date);
      await _db.setRecurringCompletion(
        taskId: task.id!,
        dateStr: dateStr,
        completed: completed,
      );
    } else {
      await _db.toggleOneOffCompleted(task.id!, completed);
    }
  }

  // ─── SUBTASKS ─────────────────────────────────────────────

  Future<void> toggleSubtaskCompleted(
    int subtaskId,
    DateTime date,
    bool completed, {
    required bool isRecurring,
  }) async {
    if (isRecurring) {
      final dateStr = WeekdayUtils.toDateString(date);
      await _db.setSubtaskCompletionForDate(
        subtaskId: subtaskId,
        dateStr: dateStr,
        completed: completed,
      );
    } else {
      await _db.toggleSubtaskCompleted(subtaskId, completed);
    }
  }

  Future<void> deleteSubtask(int id) async {
    await _db.deleteSubtask(id);
  }
}
