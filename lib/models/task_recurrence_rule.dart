/// Versão da regra de recorrência válida a partir de [effectiveFrom].
class TaskRecurrenceRule {
  int? id;
  int taskId;
  String effectiveFrom; // YYYY-MM-DD
  String recurringDays;
  String title;
  String? description;
  String? time;

  TaskRecurrenceRule({
    this.id,
    required this.taskId,
    required this.effectiveFrom,
    required this.recurringDays,
    required this.title,
    this.description,
    this.time,
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
    );
  }
}
