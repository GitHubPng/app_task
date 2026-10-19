/// Ocorrência materializada de uma tarefa recorrente em uma data concreta.
///
/// Linhas existem apenas quando há override ou cancelamento pontual.
/// Ocorrências normais são calculadas em runtime a partir da regra em [Task].
class TaskOccurrence {
  int? id;
  int taskId;
  String occurrenceDate; // YYYY-MM-DD
  String? title;
  String? description;
  String? time;
  String? endTime;
  String? breakStart;
  String? breakEnd;
  bool cancelled;

  TaskOccurrence({
    this.id,
    required this.taskId,
    required this.occurrenceDate,
    this.title,
    this.description,
    this.time,
    this.endTime,
    this.breakStart,
    this.breakEnd,
    this.cancelled = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'occurrence_date': occurrenceDate,
      'title': title,
      'description': description,
      'time': time,
      'end_time': endTime,
      'break_start': breakStart,
      'break_end': breakEnd,
      'cancelled': cancelled ? 1 : 0,
    };
  }

  factory TaskOccurrence.fromMap(Map<String, dynamic> map) {
    return TaskOccurrence(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      occurrenceDate: map['occurrence_date'] as String,
      title: map['title'] as String?,
      description: map['description'] as String?,
      time: map['time'] as String?,
      endTime: map['end_time'] as String?,
      breakStart: map['break_start'] as String?,
      breakEnd: map['break_end'] as String?,
      cancelled: (map['cancelled'] as int? ?? 0) == 1,
    );
  }
}
