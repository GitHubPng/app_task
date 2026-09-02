import 'subtask.dart';

class Task {
  int? id;
  String title;
  String? description;
  String? dueDate;
  bool completed;
  String createdAt;
  List<Subtask> subtasks;

  /// true = rotina semanal; false = tarefa avulsa
  bool isRecurring;

  /// Dias da semana: "1,3,5" (1=Seg ... 7=Dom). Nulo para avulsas.
  String? recurringDays;

  /// Horário "HH:mm" para ordenar a lista do dia.
  String? time;

  /// Arquivamento manual; não é mais setado automaticamente ao concluir avulsas.
  bool archived;

  // ─── Campos runtime (agenda / ocorrência) ─────────────────

  /// Data concreta exibida na agenda (YYYY-MM-DD).
  String? occurrenceDate;

  /// Id em task_occurrences, quando materializada.
  int? occurrenceId;

  /// true quando há linha em task_occurrences para esta data.
  bool isOccurrenceOverride;

  /// Overrides pontuais vindos de task_occurrences (não persistidos em tasks).
  String? occurrenceTitleOverride;
  String? occurrenceDescriptionOverride;
  String? occurrenceTimeOverride;

  Task({
    this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.completed = false,
    required this.createdAt,
    this.subtasks = const [],
    this.isRecurring = false,
    this.recurringDays,
    this.time,
    this.archived = false,
    this.occurrenceDate,
    this.occurrenceId,
    this.isOccurrenceOverride = false,
    this.occurrenceTitleOverride,
    this.occurrenceDescriptionOverride,
    this.occurrenceTimeOverride,
  });

  /// Título efetivo: override da ocorrência → valor da regra.
  String get effectiveTitle => occurrenceTitleOverride ?? title;

  /// Descrição efetiva: override da ocorrência → valor da regra.
  String? get effectiveDescription =>
      occurrenceDescriptionOverride ?? description;

  /// Horário efetivo: override da ocorrência → valor da regra.
  String? get effectiveTime => occurrenceTimeOverride ?? time;

  /// Converte "1,3,5" em lista de inteiros [1, 3, 5].
  List<int> get recurringDaysList {
    if (recurringDays == null || recurringDays!.trim().isEmpty) return [];
    return recurringDays!
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
  }

  /// Indica se a tarefa recorrente está agendada para o dia (1–7).
  bool occursOnWeekday(int weekday) {
    return recurringDaysList.contains(weekday);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'due_date': dueDate,
      'completed': completed ? 1 : 0,
      'created_at': createdAt,
      'is_recurring': isRecurring ? 1 : 0,
      'recurring_days': recurringDays,
      'time': time,
      'archived': archived ? 1 : 0,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String?,
      dueDate: map['due_date'] as String?,
      completed: (map['completed'] as int? ?? 0) == 1,
      createdAt: map['created_at'] as String,
      subtasks: [],
      isRecurring: (map['is_recurring'] as int? ?? 0) == 1,
      recurringDays: map['recurring_days'] as String?,
      time: map['time'] as String?,
      archived: (map['archived'] as int? ?? 0) == 1,
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
    bool? isRecurring,
    String? recurringDays,
    String? time,
    bool? archived,
    String? occurrenceDate,
    int? occurrenceId,
    bool? isOccurrenceOverride,
    String? occurrenceTitleOverride,
    String? occurrenceDescriptionOverride,
    String? occurrenceTimeOverride,
    bool clearDueDate = false,
    bool clearRecurringDays = false,
    bool clearTime = false,
    bool clearOccurrenceOverrides = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      subtasks: subtasks ?? this.subtasks,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringDays:
          clearRecurringDays ? null : (recurringDays ?? this.recurringDays),
      time: clearTime ? null : (time ?? this.time),
      archived: archived ?? this.archived,
      occurrenceDate: occurrenceDate ?? this.occurrenceDate,
      occurrenceId: occurrenceId ?? this.occurrenceId,
      isOccurrenceOverride: isOccurrenceOverride ?? this.isOccurrenceOverride,
      occurrenceTitleOverride: clearOccurrenceOverrides
          ? null
          : (occurrenceTitleOverride ?? this.occurrenceTitleOverride),
      occurrenceDescriptionOverride: clearOccurrenceOverrides
          ? null
          : (occurrenceDescriptionOverride ??
              this.occurrenceDescriptionOverride),
      occurrenceTimeOverride: clearOccurrenceOverrides
          ? null
          : (occurrenceTimeOverride ?? this.occurrenceTimeOverride),
    );
  }
}
