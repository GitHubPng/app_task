import 'subtask.dart';

class Task {
  int? id;
  String title;
  String? description;
  String? dueDate;
  bool completed;
  String createdAt;
  List<Subtask> subtasks;

  Task({
    this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.completed = false,
    required this.createdAt,
    this.subtasks = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'due_date': dueDate,
      'completed': completed ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String?,
      dueDate: map['due_date'] as String?,
      completed: (map['completed'] as int) == 1,
      createdAt: map['created_at'] as String,
      subtasks: [],
    );
  }

  Task copyWith({
    int? id,
    String? title,
    String? description,
    String? dueDate,
    bool? completed,
    String? createdAt,
    List<Subtask>? subtasks,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      subtasks: subtasks ?? this.subtasks,
    );
  }
}
