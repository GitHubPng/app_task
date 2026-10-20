import '../models/task.dart';
import '../utils/time_range.dart';

const kReminderOptions = [0, 5, 15, 30, 60];
const kDefaultReminderMinutes = 15;

/// Aviso a agendar para uma ocorrência (tarefa + data).
class PlannedReminder {
  final int id;
  final DateTime fireAt;
  final String title;
  final String body;

  const PlannedReminder({
    required this.id,
    required this.fireAt,
    required this.title,
    required this.body,
  });
}

/// Id estável por (tarefa, data), para o aviso poder ser substituído.
int reminderId(int taskId, DateTime day) {
  final days = DateTime.utc(day.year, day.month, day.day)
      .difference(DateTime.utc(2020, 1, 1))
      .inDays;
  return taskId * 10000 + days % 10000;
}

/// Avisos das tarefas efetivas de cada dia, ordenados por horário.
/// Ignora lembrete desligado, sem início, concluída e aviso no passado.
List<PlannedReminder> planReminders(
  Map<DateTime, List<Task>> tasksByDay,
  DateTime now,
) {
  final planned = <PlannedReminder>[];
  tasksByDay.forEach((day, tasks) {
    for (final task in tasks) {
      if (!task.reminderEnabled || task.completed) continue;
      final range = task.effectiveRange;
      final start = TimeRange.toMinutes(range.start);
      if (start == null) continue;

      final minutes = task.reminderMinutesBefore ?? kDefaultReminderMinutes;
      // Horário de parede (não Duration): correto em dia de horário de verão.
      final fireAt = DateTime(day.year, day.month, day.day, 0, start - minutes);
      if (!fireAt.isAfter(now)) continue;

      final lead = minutes == 0
          ? 'Começa agora'
          : 'Começa às ${range.start} (em $minutes min)';
      planned.add(
        PlannedReminder(
          id: reminderId(task.id!, day),
          fireAt: fireAt,
          title: task.effectiveTitle,
          body: range.hasEnd ? '$lead · ${range.label}' : lead,
        ),
      );
    }
  });
  planned.sort((a, b) => a.fireAt.compareTo(b.fireAt));
  return planned;
}

PlannedReminder? nextReminder(List<PlannedReminder> planned, DateTime now) {
  PlannedReminder? next;
  for (final r in planned) {
    if (!r.fireAt.isAfter(now)) continue;
    if (next == null || r.fireAt.isBefore(next.fireAt)) next = r;
  }
  return next;
}
