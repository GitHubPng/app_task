class Subtask {
  int? id;
  int taskId;
  String title;
  bool completed;

  Subtask({
    this.id,
    required this.taskId,
    required this.title,
    this.completed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'title': title,
      'completed': completed ? 1 : 0,
    };
  }

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      title: map['title'] as String,
      completed: (map['completed'] as int) == 1,
    );
  }

  Subtask copyWith({
    int? id,
    int? taskId,
    String? title,
    bool? completed,
  }) {
    return Subtask(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      completed: completed ?? this.completed,
    );
  }
}
