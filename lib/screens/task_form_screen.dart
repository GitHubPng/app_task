import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/subtask.dart';
import '../services/task_service.dart';
import '../utils/app_theme.dart';
import '../utils/validators.dart';
import '../utils/weekday_utils.dart';
import '../widgets/subtask_widget.dart';

class TaskFormScreen extends StatefulWidget {
  final Task? task; // null = create mode, non-null = edit mode

  /// Quando definido, edição afeta somente esta ocorrência da rotina.
  final String? occurrenceDate;

  const TaskFormScreen({super.key, this.task, this.occurrenceDate});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subtaskController = TextEditingController();
  final _taskService = TaskService();

  /// true = recorrente semanal; false = avulsa
  bool _isRecurring = true;

  final Set<int> _selectedDays = {};
  String? _selectedTime;
  String? _selectedDate;
  List<Subtask> _subtasks = [];
  bool _isSaving = false;

  bool get _isEditMode => widget.task != null;

  /// Edição pontual de uma ocorrência recorrente (não altera a regra).
  bool get _isOccurrenceEdit =>
      _isEditMode &&
      widget.task!.isRecurring &&
      widget.occurrenceDate != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final t = widget.task!;
      _titleController.text =
          _isOccurrenceEdit ? t.effectiveTitle : t.title;
      _descriptionController.text =
          (_isOccurrenceEdit ? t.effectiveDescription : t.description) ?? '';
      _isRecurring = t.isRecurring;
      _selectedDate = t.dueDate;
      _selectedTime =
          _isOccurrenceEdit ? t.effectiveTime : t.time;
      _selectedDays.addAll(t.recurringDaysList);
      _subtasks = List.from(t.subtasks);
    } else {
      // Nova tarefa: dia de hoje pré-marcado na rotina.
      _selectedDays.add(DateTime.now().weekday);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate != null
        ? DateTime.tryParse(_selectedDate!) ?? now
        : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = WeekdayUtils.toDateString(picked);
      });
    }
  }

  Future<void> _pickTime() async {
    TimeOfDay initial = TimeOfDay.now();
    if (_selectedTime != null && _selectedTime!.contains(':')) {
      final parts = _selectedTime!.split(':');
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) {
        initial = TimeOfDay(hour: h, minute: m);
      }
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedTime =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _addSubtask() {
    final text = _subtaskController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _subtasks.add(Subtask(taskId: 0, title: text));
      _subtaskController.clear();
    });
  }

  void _removeSubtask(int index) {
    setState(() => _subtasks.removeAt(index));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // RN-NOVA-01: recorrente precisa de pelo menos um dia (exceto edição de ocorrência).
    if (_isRecurring && !_isOccurrenceEdit && _selectedDays.isEmpty) {
      _showSnack('Selecione ao menos um dia da semana.', isError: true);
      return;
    }

    // RN02: data não retroativa (só avulsas).
    if (!_isRecurring &&
        _selectedDate != null &&
        Validators.isDateInPast(_selectedDate!)) {
      _showSnack('A data não pode ser anterior à data atual.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now().toIso8601String();
      final recurringDays =
          _isRecurring ? WeekdayUtils.daysToStorage(_selectedDays.toList()) : null;

      if (_isEditMode) {
        if (_isOccurrenceEdit) {
          final date = DateTime.parse(widget.occurrenceDate!);
          await _taskService.updateOccurrence(
            widget.task!.id!,
            date,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            time: _selectedTime,
          );
          if (mounted) {
            _showSnack('Ocorrência atualizada!');
            Navigator.of(context).pop(true);
          }
        } else {
          final toSave = Task(
            id: widget.task!.id,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            dueDate: _isRecurring ? null : _selectedDate,
            completed: widget.task!.completed,
            createdAt: widget.task!.createdAt,
            isRecurring: _isRecurring,
            recurringDays: recurringDays,
            time: _selectedTime,
            archived: widget.task!.archived,
          );
          await _taskService.updateTask(toSave, _subtasks);
          if (mounted) {
            _showSnack('Tarefa atualizada!');
            Navigator.of(context).pop(true);
          }
        }
      } else {
        final task = Task(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          dueDate: _isRecurring ? null : _selectedDate,
          createdAt: now,
          isRecurring: _isRecurring,
          recurringDays: recurringDays,
          time: _selectedTime,
        );
        await _taskService.createTask(task, _subtasks);
        if (mounted) {
          _showSnack('Tarefa criada!');
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Erro ao salvar tarefa.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _isOccurrenceEdit
              ? 'Editar Ocorrência'
              : (_isEditMode ? 'Editar Tarefa' : 'Nova Tarefa'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        actions: [
          if (_isEditMode)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: const Text(
                'Salvar',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Título *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                validator: Validators.validateTitle,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Nome da tarefa',
                  prefixIcon:
                      Icon(Icons.title_rounded, color: AppTheme.primary),
                ),
              ),
              const SizedBox(height: 20),

              _label('Descrição'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Detalhes opcionais...',
                  prefixIcon:
                      Icon(Icons.notes_rounded, color: AppTheme.primary),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),

              if (_isOccurrenceEdit) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    'Alterações nesta tela afetam somente a ocorrência de '
                    '${Validators.formatDateDisplay(widget.occurrenceDate)}.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Tipo de tarefa — bloqueado em edição de ocorrência.
              if (!_isOccurrenceEdit) ...[
                _label('Tipo de tarefa'),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Recorrente'),
                      icon: Icon(Icons.repeat_rounded, size: 18),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Avulsa'),
                      icon: Icon(Icons.event_rounded, size: 18),
                    ),
                  ],
                  selected: {_isRecurring},
                  onSelectionChanged: (set) {
                    setState(() => _isRecurring = set.first);
                  },
                ),
                const SizedBox(height: 20),
              ],

              if (_isRecurring && !_isOccurrenceEdit) ...[
                _label('Dias da semana *'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (i) {
                    final day = i + 1;
                    final selected = _selectedDays.contains(day);
                    return FilterChip(
                      label: Text(WeekdayUtils.shortLabels[i]),
                      selected: selected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedDays.add(day);
                          } else {
                            _selectedDays.remove(day);
                          }
                        });
                      },
                      selectedColor: AppTheme.primary.withOpacity(0.18),
                      checkmarkColor: AppTheme.primary,
                      labelStyle: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                      ),
                      side: BorderSide(
                        color: selected ? AppTheme.primary : AppTheme.border,
                      ),
                    );
                  }),
                ),
              ] else if (!_isOccurrenceEdit) ...[
                _label('Data de Vencimento'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDate,
                  child: AbsorbPointer(
                    child: TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'Selecionar data',
                        prefixIcon: const Icon(
                          Icons.calendar_month_rounded,
                          color: AppTheme.primary,
                        ),
                        suffixIcon: _selectedDate != null
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () =>
                                    setState(() => _selectedDate = null),
                              )
                            : null,
                      ),
                      controller: TextEditingController(
                        text: Validators.formatDateDisplay(_selectedDate),
                      ),
                    ),
                  ),
                ),
              ],

              // Horário para recorrentes e avulsas — mantém a lista do dia ordenada.
              const SizedBox(height: 20),
              _label('Horário'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickTime,
                child: AbsorbPointer(
                  child: TextFormField(
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: 'Opcional — ordena a lista do dia',
                      prefixIcon: const Icon(
                        Icons.schedule_rounded,
                        color: AppTheme.primary,
                      ),
                      suffixIcon: _selectedTime != null
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () =>
                                  setState(() => _selectedTime = null),
                            )
                          : null,
                    ),
                    controller: TextEditingController(
                      text: _selectedTime ?? '',
                    ),
                  ),
                ),
              ),

              if (!_isOccurrenceEdit) ...[
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _label('Etapas (Subtarefas)'),
                    Text(
                      '${_subtasks.length} ${_subtasks.length == 1 ? 'etapa' : 'etapas'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _subtaskController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Nova etapa...',
                          prefixIcon: Icon(
                            Icons.add_task_rounded,
                            color: AppTheme.primary,
                          ),
                        ),
                        onFieldSubmitted: (_) => _addSubtask(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _addSubtask,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Icon(Icons.add, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_subtasks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: _subtasks.asMap().entries.map((entry) {
                        final i = entry.key;
                        final sub = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: SubtaskWidget(
                            subtask: sub,
                            onDelete: () => _removeSubtask(i),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditMode ? 'Salvar Alterações' : 'Criar Tarefa',
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }
}
