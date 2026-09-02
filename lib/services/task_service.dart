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

  Future<List<Task>> getTasksForDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final dateStr = WeekdayUtils.toDateString(normalized);
    return await _db.getTasksForDate(
      weekday: normalized.weekday,
      dateStr: dateStr,
    );
  }

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

    if (task.isRecurring && task.recurringDays != null) {
      final effectiveFrom = _effectiveFromString(task.createdAt);
      await _db.upsertRecurrenceRule(
        taskId: taskId,
        effectiveFrom: effectiveFrom,
        recurringDays: task.recurringDays!,
        title: task.title,
        description: task.description,
        time: task.time,
      );
    }

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

  /// Nova versão da regra recorrente a partir de [effectiveFrom].
  Future<void> updateRecurrenceRule({
    required int taskId,
    required DateTime effectiveFrom,
    required String recurringDays,
    required String title,
    String? description,
    String? time,
    List<Subtask>? subtasks,
  }) async {
    final effectiveStr = WeekdayUtils.toDateString(effectiveFrom);
    await _db.upsertRecurrenceRule(
      taskId: taskId,
      effectiveFrom: effectiveStr,
      recurringDays: recurringDays,
      title: title,
      description: description,
      time: time,
    );

    final current = await _db.getTaskById(taskId);
    if (current != null) {
      await _db.updateTask(
        current.copyWith(
          title: title,
          description: description,
          time: time,
          recurringDays: recurringDays,
          isRecurring: true,
          clearDueDate: true,
        ),
      );
    }

    if (subtasks != null) {
      await _db.deleteSubtasksByTask(taskId);
      for (final sub in subtasks) {
        await _db.insertSubtask(sub.copyWith(taskId: taskId));
      }
    }
  }

  /// Converte avulsa em recorrente preservando a data original quando necessário.
  Future<void> convertToRecurring({
    required Task task,
    required DateTime effectiveFrom,
    required String recurringDays,
    required String title,
    String? description,
    String? time,
    required List<Subtask> subtasks,
  }) async {
    final taskId = task.id!;
    final dueDate = task.dueDate;
    final wasCompleted = task.completed;
    final ruleStart = dueDate ?? WeekdayUtils.toDateString(effectiveFrom);

    await _db.updateTask(
      task.copyWith(
        title: title,
        description: description,
        time: time,
        isRecurring: true,
        recurringDays: recurringDays,
        completed: false,
        clearDueDate: true,
      ),
    );

    if (wasCompleted) {
      final completionDate = dueDate ?? WeekdayUtils.toDateString(effectiveFrom);
      await _db.setRecurringCompletion(
        taskId: taskId,
        dateStr: completionDate,
        completed: true,
      );
    }

    if (dueDate != null) {
      final weekday = DateTime.parse(dueDate).weekday;
      if (!WeekdayUtils.daysFromStorage(recurringDays).contains(weekday)) {
        await _db.ensureOccurrenceAnchor(taskId: taskId, dateStr: dueDate);
      }
    }

    await _db.upsertRecurrenceRule(
      taskId: taskId,
      effectiveFrom: ruleStart,
      recurringDays: recurringDays,
      title: title,
      description: description,
      time: time,
    );

    await _db.deleteSubtasksByTask(taskId);
    for (final sub in subtasks) {
      await _db.insertSubtask(sub.copyWith(taskId: taskId));
    }
  }

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

  Future<void> cancelOccurrence(int taskId, DateTime date) async {
    final dateStr = WeekdayUtils.toDateString(date);
    await _db.cancelOccurrence(taskId: taskId, dateStr: dateStr);
  }

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

  String _effectiveFromString(String createdAt) {
    if (createdAt.length >= 10) {
      return createdAt.substring(0, 10);
    }
    return WeekdayUtils.todayString();
  }
}
