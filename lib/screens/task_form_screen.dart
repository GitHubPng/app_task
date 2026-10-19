import 'package:flutter/material.dart';
import '../models/task_form_mode.dart';
import '../models/task.dart';
import '../models/subtask.dart';
import '../services/notification_service.dart';
import '../services/reminder_planner.dart';
import '../services/task_service.dart';
import '../utils/app_theme.dart';
import '../utils/time_range.dart';
import '../utils/validators.dart';
import '../utils/weekday_utils.dart';
import '../widgets/subtask_widget.dart';

class TaskFormScreen extends StatefulWidget {
  final Task? task;
  final TaskFormMode mode;

  /// Data da ocorrência em edição pontual.
  final String? occurrenceDate;

  /// Data inicial sugerida para alteração da rotina.
  final DateTime? ruleEffectiveFromDefault;

  const TaskFormScreen({
    super.key,
    this.task,
    this.mode = TaskFormMode.standard,
    this.occurrenceDate,
    this.ruleEffectiveFromDefault,
  });

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
  String? _selectedEndTime;
  String? _selectedBreakStart;
  String? _selectedBreakEnd;
  bool _breakOpen = false;
  bool _reminderEnabled = false;
  int _reminderMinutes = kDefaultReminderMinutes;
  String? _selectedDate;
  String? _ruleEffectiveFrom;
  List<Subtask> _subtasks = [];
  bool _isSaving = false;
  bool _wasRecurring = false;

  bool get _isEditMode => widget.task != null;

  bool get _isOccurrenceEdit =>
      _isEditMode && widget.mode == TaskFormMode.occurrence;

  bool get _isRuleEdit => _isEditMode && widget.mode == TaskFormMode.rule;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final t = widget.task!;
      _wasRecurring = t.isRecurring;
      _titleController.text = _isOccurrenceEdit ? t.effectiveTitle : t.title;
      _descriptionController.text = _isOccurrenceEdit
          ? (t.effectiveDescription ?? '')
          : (t.description ?? '');
      _isRecurring = t.isRecurring || _isRuleEdit;
      _selectedDate = t.dueDate;
      // Valores efetivos já normalizam '' (removido) para null.
      _selectedTime = _isOccurrenceEdit ? t.effectiveTime : _orNull(t.time);
      _selectedEndTime =
          _isOccurrenceEdit ? t.effectiveEndTime : _orNull(t.endTime);
      _selectedBreakStart =
          _isOccurrenceEdit ? t.effectiveBreakStart : _orNull(t.breakStart);
      _selectedBreakEnd =
          _isOccurrenceEdit ? t.effectiveBreakEnd : _orNull(t.breakEnd);
      _breakOpen = _selectedBreakStart != null || _selectedBreakEnd != null;
      _reminderEnabled = t.reminderEnabled;
      // Valor fora das opções (ex.: backup editado) quebraria o dropdown.
      final minutes = t.reminderMinutesBefore;
      _reminderMinutes = kReminderOptions.contains(minutes)
          ? minutes!
          : kDefaultReminderMinutes;
      _selectedDays.addAll(
        _isOccurrenceEdit || _isRuleEdit
            ? t.displayRecurringDaysList
            : t.recurringDaysList,
      );
      _subtasks = List.from(t.subtasks);

      if (_isRuleEdit) {
        final defaultDate = widget.ruleEffectiveFromDefault ?? DateTime.now();
        _ruleEffectiveFrom = WeekdayUtils.toDateString(defaultDate);
      }
    } else {
      // Nova tarefa: hoje pré-marcado na rotina e como data da avulsa.
      final now = DateTime.now();
      _selectedDays.add(now.weekday);
      _selectedDate = WeekdayUtils.toDateString(now);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  Future<void> _pickRuleEffectiveFrom() async {
    final now = DateTime.now();
    final initial = _ruleEffectiveFrom != null
        ? DateTime.tryParse(_ruleEffectiveFrom!) ?? now
        : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
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
        _ruleEffectiveFrom = WeekdayUtils.toDateString(picked);
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial =
        _selectedDate != null ? DateTime.tryParse(_selectedDate!) ?? now : now;

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

  static String? _orNull(String? v) => (v == null || v.isEmpty) ? null : v;

  Future<String?> _pickTime(String? current) async {
    var initial = TimeOfDay.now();
    final minutes = TimeRange.toMinutes(current);
    if (minutes != null) {
      initial = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
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
    if (picked == null) return null;
    return '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
  }

  // Limpar início limpa fim e pausa; limpar fim limpa pausa.
  void _clearStart() => setState(() {
        _selectedTime = null;
        _selectedEndTime = null;
        _reminderEnabled = false;
        _resetBreak();
      });

  Future<void> _toggleReminder(bool enabled) async {
    if (!enabled) {
      setState(() => _reminderEnabled = false);
      return;
    }
    setState(() => _reminderEnabled = true);
    var granted = false;
    try {
      granted = await NotificationService.instance.requestPermission();
    } catch (_) {}
    if (!granted && mounted) {
      setState(() => _reminderEnabled = false);
      _showSnack(
        'Permita notificações nas configurações do Android para receber '
        'lembretes.',
        isError: true,
      );
    }
  }

  // Lembrete só faz sentido com início definido.
  bool get _saveReminder => _reminderEnabled && _selectedTime != null;

  static String _reminderLabel(int minutes) => switch (minutes) {
        0 => 'Na hora',
        60 => '1 h antes',
        _ => '$minutes min antes',
      };

  void _clearEnd() => setState(() {
        _selectedEndTime = null;
        _resetBreak();
      });

  void _clearBreak() => setState(_resetBreak);

  void _resetBreak() {
    _selectedBreakStart = null;
    _selectedBreakEnd = null;
    _breakOpen = false;
  }

  TimeRange get _range => TimeRange(
        start: _selectedTime,
        end: _selectedEndTime,
        breakStart: _selectedBreakStart,
        breakEnd: _selectedBreakEnd,
      );

  /// Datas onde a tarefa salva vai aparecer, para checar sobreposição.
  List<DateTime> _conflictDates() {
    if (_isOccurrenceEdit) return [DateTime.parse(widget.occurrenceDate!)];
    if (!_isRecurring) return [DateTime.parse(_selectedDate!)];
    final from = _isRuleEdit
        ? DateTime.parse(_ruleEffectiveFrom!)
        : (!_wasRecurring && _isEditMode && _selectedDate != null)
            ? DateTime.parse(_selectedDate!)
            : DateTime.now();
    return TaskService.datesForRule(from, _selectedDays.toList());
  }

  /// true = pode salvar (sem conflito ou usuário confirmou).
  Future<bool> _confirmConflicts() async {
    final conflicts = await _taskService.findConflicts(
      range: _range,
      dates: _conflictDates(),
      excludeTaskId: widget.task?.id,
    );
    if (conflicts.isEmpty || !mounted) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Conflito de horário',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Este horário se sobrepõe a:',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            ...conflicts.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${t.effectiveTitle} · ${t.effectiveRange.label} · '
                  '${Validators.formatDateDisplay(t.occurrenceDate)}',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Salvar mesmo assim',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
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

    if (_isRuleEdit &&
        (_ruleEffectiveFrom == null || _ruleEffectiveFrom!.isEmpty)) {
      _showSnack('Selecione a data de início da rotina.', isError: true);
      return;
    }

    if (!_isRecurring && _selectedDate == null) {
      _showSnack('Selecione a data da tarefa avulsa.', isError: true);
      return;
    }

    final rangeError = _range.validate();
    if (rangeError != null) {
      _showSnack(rangeError, isError: true);
      return;
    }

    // RN02: data não retroativa (só avulsas novas).
    if (!_isRecurring &&
        !_isEditMode &&
        _selectedDate != null &&
        Validators.isDateInPast(_selectedDate!)) {
      _showSnack('A data não pode ser anterior à data atual.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (!await _confirmConflicts()) return;
      final now = DateTime.now().toIso8601String();
      final recurringDays = _isRecurring
          ? WeekdayUtils.daysToStorage(_selectedDays.toList())
          : null;

      if (_isEditMode) {
        if (_isOccurrenceEdit) {
          final t = widget.task!;
          final date = DateTime.parse(widget.occurrenceDate!);
          // Override só do que difere da regra; '' = removido nesta data.
          await _taskService.updateOccurrence(
            t.id!,
            date,
            title: _overrideOrNull(
              _titleController.text.trim(),
              t.ruleTitleForDate ?? t.title,
            ),
            description: _overrideOrNull(
              _descriptionController.text.trim(),
              t.ruleDescriptionForDate ?? t.description,
            ),
            time: _overrideOrNull(
              _selectedTime ?? '',
              t.ruleTimeForDate ?? t.time,
            ),
            endTime: _overrideOrNull(
              _selectedEndTime ?? '',
              t.ruleEndTimeForDate ?? t.endTime,
            ),
            breakStart: _overrideOrNull(
              _selectedBreakStart ?? '',
              t.ruleBreakStartForDate ?? t.breakStart,
            ),
            breakEnd: _overrideOrNull(
              _selectedBreakEnd ?? '',
              t.ruleBreakEndForDate ?? t.breakEnd,
            ),
          );
          if (mounted) {
            _showSnack('Ocorrência atualizada!');
            Navigator.of(context).pop(true);
          }
        } else if (_isRuleEdit) {
          await _taskService.updateRecurrenceRule(
            taskId: widget.task!.id!,
            effectiveFrom: DateTime.parse(_ruleEffectiveFrom!),
            recurringDays: recurringDays!,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            time: _selectedTime,
            endTime: _selectedEndTime,
            breakStart: _selectedBreakStart,
            breakEnd: _selectedBreakEnd,
            reminderEnabled: _saveReminder,
            reminderMinutesBefore: _reminderMinutes,
            subtasks: _subtasks,
          );
          if (mounted) {
            _showSnack('Rotina atualizada!');
            Navigator.of(context).pop(true);
          }
        } else if (!_wasRecurring && _isRecurring) {
          await _taskService.convertToRecurring(
            task: widget.task!,
            effectiveFrom: _selectedDate != null
                ? DateTime.parse(_selectedDate!)
                : DateTime.now(),
            recurringDays: recurringDays!,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            time: _selectedTime,
            endTime: _selectedEndTime,
            breakStart: _selectedBreakStart,
            breakEnd: _selectedBreakEnd,
            reminderEnabled: _saveReminder,
            reminderMinutesBefore: _reminderMinutes,
            subtasks: _subtasks,
          );
          if (mounted) {
            _showSnack('Tarefa convertida em rotina!');
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
            endTime: _selectedEndTime,
            breakStart: _selectedBreakStart,
            breakEnd: _selectedBreakEnd,
            reminderEnabled: _saveReminder,
            reminderMinutesBefore: _reminderMinutes,
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
          endTime: _selectedEndTime,
          breakStart: _selectedBreakStart,
          breakEnd: _selectedBreakEnd,
          reminderEnabled: _saveReminder,
          reminderMinutesBefore: _reminderMinutes,
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

  String? _overrideOrNull(String value, String? ruleValue) {
    return value == (ruleValue ?? '') ? null : value;
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
              : _isRuleEdit
                  ? 'Editar Rotina'
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

              if (_isRuleEdit) ...[
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
                  child: const Text(
                    'Alterações nesta tela atualizam a regra da rotina a partir '
                    'da data escolhida. Ocorrências anteriores permanecem intactas.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _label('Válida a partir de *'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickRuleEffectiveFrom,
                  child: AbsorbPointer(
                    child: TextFormField(
                      readOnly: true,
                      decoration: const InputDecoration(
                        hintText: 'Data de início da nova regra',
                        prefixIcon: Icon(
                          Icons.calendar_month_rounded,
                          color: AppTheme.primary,
                        ),
                      ),
                      controller: TextEditingController(
                        text: Validators.formatDateDisplay(_ruleEffectiveFrom),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

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

              // Tipo de tarefa — bloqueado em edição de ocorrência/rotina.
              if (!_isOccurrenceEdit && !_isRuleEdit) ...[
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
                    setState(() {
                      _isRecurring = set.first;
                      if (!_isRecurring && _selectedDate == null) {
                        _selectedDate =
                            WeekdayUtils.toDateString(DateTime.now());
                      }
                    });
                  },
                ),
                const SizedBox(height: 20),
              ],

              if (_isRecurring && !_isOccurrenceEdit) ...[
                _label('Dias da semana *'),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(7, (i) {
                    final day = i + 1;
                    final selected = _selectedDays.contains(day);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: FilterChip(
                          label: Text(
                            WeekdayUtils.shortLabels[i],
                            style: const TextStyle(fontSize: 11),
                          ),
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
                          showCheckmark: true,
                          padding: EdgeInsets.zero,
                          labelPadding: EdgeInsets.zero,
                          side: BorderSide(
                            color:
                                selected ? AppTheme.primary : AppTheme.border,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ] else if (!_isOccurrenceEdit && !_isRuleEdit) ...[
                _label('Data *'),
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
                      ),
                      controller: TextEditingController(
                        text: Validators.formatDateDisplay(_selectedDate),
                      ),
                    ),
                  ),
                ),
              ],

              // Horário: início; fim após início; pausa após fim.
              const SizedBox(height: 20),
              _label('Horário'),
              const SizedBox(height: 8),
              _timeField(
                hint: 'Início — opcional, ordena a lista do dia',
                value: _selectedTime,
                icon: Icons.schedule_rounded,
                onPicked: (v) => setState(() => _selectedTime = v),
                onClear: _clearStart,
              ),
              if (_selectedTime != null) ...[
                const SizedBox(height: 8),
                _timeField(
                  hint: 'Fim (opcional)',
                  value: _selectedEndTime,
                  icon: Icons.flag_outlined,
                  onPicked: (v) => setState(() => _selectedEndTime = v),
                  onClear: _clearEnd,
                ),
              ],
              if (_selectedEndTime != null && !_breakOpen)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _breakOpen = true),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar pausa'),
                  ),
                ),
              if (_selectedEndTime != null && _breakOpen) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    _label('Pausa'),
                    const Spacer(),
                    TextButton(
                      onPressed: _clearBreak,
                      child: const Text('Remover pausa'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _timeField(
                        hint: 'De',
                        value: _selectedBreakStart,
                        icon: Icons.pause_circle_outline,
                        onPicked: (v) =>
                            setState(() => _selectedBreakStart = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _timeField(
                        hint: 'Até',
                        value: _selectedBreakEnd,
                        icon: Icons.play_circle_outline,
                        onPicked: (v) => setState(() => _selectedBreakEnd = v),
                      ),
                    ),
                  ],
                ),
              ],

              // Lembrete: por tarefa (não por ocorrência), exige início.
              if (!_isOccurrenceEdit && _selectedTime != null) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Lembrete'),
                  secondary: const Icon(
                    Icons.notifications_active_outlined,
                    color: AppTheme.primary,
                  ),
                  value: _reminderEnabled,
                  onChanged: _toggleReminder,
                ),
                if (_reminderEnabled)
                  DropdownButtonFormField<int>(
                    value: _reminderMinutes,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(
                        Icons.timer_outlined,
                        color: AppTheme.primary,
                      ),
                    ),
                    items: [
                      for (final m in kReminderOptions)
                        DropdownMenuItem(
                          value: m,
                          child: Text(_reminderLabel(m)),
                        ),
                    ],
                    onChanged: (m) {
                      if (m != null) setState(() => _reminderMinutes = m);
                    },
                  ),
              ],

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

  /// Campo de horário: toque abre o seletor; X (fora do AbsorbPointer,
  /// para receber o toque) limpa.
  Widget _timeField({
    required String hint,
    required String? value,
    required IconData icon,
    required ValueChanged<String> onPicked,
    VoidCallback? onClear,
  }) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final picked = await _pickTime(value);
              if (picked != null) onPicked(picked);
            },
            child: AbsorbPointer(
              child: TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  hintText: hint,
                  prefixIcon: Icon(icon, color: AppTheme.primary),
                ),
                controller: TextEditingController(text: value ?? ''),
              ),
            ),
          ),
        ),
        if (value != null && onClear != null)
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Limpar',
            onPressed: onClear,
          ),
      ],
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
