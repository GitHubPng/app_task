/// Versão da regra de recorrência válida a partir de [effectiveFrom].
class TaskRecurrenceRule {
  int? id;
  int taskId;
  String effectiveFrom; // YYYY-MM-DD
  String recurringDays;
  String title;
  String? description;
  String? time;
  String? endTime;
  String? breakStart;
  String? breakEnd;

  TaskRecurrenceRule({
    this.id,
    required this.taskId,
    required this.effectiveFrom,
    required this.recurringDays,
    required this.title,
    this.description,
    this.time,
    this.endTime,
    this.breakStart,
    this.breakEnd,
  });

  List<int> get recurringDaysList {
    return recurringDays
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList()
      ..sort();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'effective_from': effectiveFrom,
      'recurring_days': recurringDays,
      'title': title,
      'description': description,
      'time': time,
      'end_time': endTime,
      'break_start': breakStart,
      'break_end': breakEnd,
    };
  }

  factory TaskRecurrenceRule.fromMap(Map<String, dynamic> map) {
    return TaskRecurrenceRule(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      effectiveFrom: map['effective_from'] as String,
      recurringDays: map['recurring_days'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      time: map['time'] as String?,
      endTime: map['end_time'] as String?,
      breakStart: map['break_start'] as String?,
      breakEnd: map['break_end'] as String?,
    );
  }
}
