/// Registro de conclusão de tarefa recorrente em uma data específica.
///
/// Reset diário automático: ao virar o dia, não existe linha para a nova
/// data, então a tarefa aparece desmarcada sem job/scheduler.
class TaskCompletion {
  int? id;
  int taskId;
  String completionDate; // YYYY-MM-DD
  bool completed;

  TaskCompletion({
    this.id,
    required this.taskId,
    required this.completionDate,
    this.completed = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'completion_date': completionDate,
      'completed': completed ? 1 : 0,
    };
  }

  factory TaskCompletion.fromMap(Map<String, dynamic> map) {
    return TaskCompletion(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      completionDate: map['completion_date'] as String,
      completed: (map['completed'] as int? ?? 1) == 1,
    );
  }
}
