import '../models/task.dart';
import '../utils/weekday_utils.dart';

/// Resumo de uma semana (segunda a domingo).
class WeekStats {
  final DateTime weekStart;
  final int total;
  final int done;

  const WeekStats({
    required this.weekStart,
    required this.total,
    required this.done,
  });

  /// Fração concluída; null quando não houve tarefas ("sem dados").
  double? get rate => total == 0 ? null : done / total;
}

/// Semanas da mais recente (a de [today]) para a mais antiga.
/// Conta as tarefas efetivas de cada dia até [today], inclusive.
List<WeekStats> computeWeekStats(
  Map<DateTime, List<Task>> tasksByDay,
  DateTime today, {
  int weeks = 8,
}) {
  final todayDate = DateTime(today.year, today.month, today.day);
  final current = WeekdayUtils.weekStart(todayDate);
  final starts = [
    for (var i = 0; i < weeks; i++) WeekdayUtils.addWeeks(current, -i),
  ];
  final totals = List.filled(weeks, 0);
  final dones = List.filled(weeks, 0);

  tasksByDay.forEach((day, tasks) {
    final date = DateTime(day.year, day.month, day.day);
    if (date.isAfter(todayDate)) return;
    final index = starts.indexOf(WeekdayUtils.weekStart(date));
    if (index < 0) return;
    totals[index] += tasks.length;
    dones[index] += tasks.where((t) => t.completed).length;
  });

  return [
    for (var i = 0; i < weeks; i++)
      WeekStats(weekStart: starts[i], total: totals[i], done: dones[i]),
  ];
}

/// Variação em pontos percentuais da semana atual vs a anterior.
int? weekDelta(List<WeekStats> stats) {
  if (stats.length < 2) return null;
  final current = stats[0].rate;
  final previous = stats[1].rate;
  if (current == null || previous == null) return null;
  return ((current - previous) * 100).round();
}
