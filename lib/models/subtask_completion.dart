/// Conclusão de subtarefa de rotina recorrente em uma data específica.
class SubtaskCompletion {
  int? id;
  int subtaskId;
  String occurrenceDate; // YYYY-MM-DD
  bool completed;

  SubtaskCompletion({
    this.id,
    required this.subtaskId,
    required this.occurrenceDate,
    this.completed = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subtask_id': subtaskId,
      'occurrence_date': occurrenceDate,
      'completed': completed ? 1 : 0,
    };
  }

  factory SubtaskCompletion.fromMap(Map<String, dynamic> map) {
    return SubtaskCompletion(
      id: map['id'] as int?,
      subtaskId: map['subtask_id'] as int,
      occurrenceDate: map['occurrence_date'] as String,
      completed: (map['completed'] as int? ?? 1) == 1,
    );
  }
}
