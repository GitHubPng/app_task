import 'package:flutter/material.dart';
import '../models/task_form_mode.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../utils/app_theme.dart';
import '../utils/validators.dart';
import '../utils/weekday_utils.dart';
import '../widgets/empty_state.dart';
import '../widgets/task_tile.dart';
import 'archived_screen.dart';
import 'task_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _taskService = TaskService();
  final _searchController = TextEditingController();

  List<Task> _tasks = [];
  bool _isLoading = true;
  String _searchQuery = '';

  /// Segunda-feira da semana selecionada.
  late DateTime _selectedWeekStart;

  /// Dia selecionado dentro da semana (1=Seg ... 7=Dom).
  late int _selectedWeekday;

  DateTime get _selectedDate =>
      WeekdayUtils.dateInWeek(_selectedWeekStart, _selectedWeekday);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedWeekStart = WeekdayUtils.weekStart(now);
    _selectedWeekday = now.weekday;
    _loadTasks();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
      _loadTasks(query: _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks({String? query}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final q = query?.isNotEmpty == true ? query : null;
    final tasks = q != null
        ? await _taskService.getAllTasks(
            searchQuery: q,
            date: _selectedDate,
          )
        : await _taskService.getTasksForDate(_selectedDate);

    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedWeekStart = WeekdayUtils.weekStart(now);
      _selectedWeekday = now.weekday;
    });
    _loadTasks(query: _searchQuery);
  }

  void _changeWeek(int delta) {
    setState(() {
      _selectedWeekStart = WeekdayUtils.addWeeks(_selectedWeekStart, delta);
    });
    _loadTasks(query: _searchQuery);
  }

  Future<void> _openForm({Task? task}) async {
    if (task != null && task.isRecurring) {
      await _openRecurringEditChoice(task);
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(task: task),
        fullscreenDialog: true,
      ),
    );
    if (result == true) _loadTasks(query: _searchQuery);
  }

  Future<void> _openRecurringEditChoice(Task task) async {
    final choice = await showModalBottomSheet<TaskFormMode>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_note_outlined),
              title: const Text('Editar esta ocorrência'),
              subtitle: Text(
                Validators.formatDateDisplay(task.occurrenceDate),
              ),
              onTap: () => Navigator.pop(ctx, TaskFormMode.occurrence),
            ),
            ListTile(
              leading: const Icon(Icons.repeat_rounded),
              title: const Text('Editar rotina'),
              subtitle: const Text('Dias, horário e regra a partir de uma data'),
              onTap: () => Navigator.pop(ctx, TaskFormMode.rule),
            ),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(
          task: task,
          mode: choice,
          occurrenceDate: choice == TaskFormMode.occurrence
              ? task.occurrenceDate
              : null,
          ruleEffectiveFromDefault: _selectedDate,
        ),
        fullscreenDialog: true,
      ),
    );
    if (result == true) _loadTasks(query: _searchQuery);
  }

  Future<void> _openArchived() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ArchivedScreen()),
    );
  }

  Future<void> _confirmDelete(Task task) async {
    final isOccurrenceCancel = task.isRecurring && task.occurrenceDate != null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isOccurrenceCancel ? 'Excluir esta ocorrência?' : 'Excluir tarefa?',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          isOccurrenceCancel
              ? 'A ocorrência "${task.effectiveTitle}" em ${Validators.formatDateDisplay(task.occurrenceDate)} será removida desta data. A rotina continuará nos outros dias.'
              : 'A tarefa "${task.title}" será removida permanentemente. Esta ação não pode ser desfeita.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              isOccurrenceCancel ? 'Excluir ocorrência' : 'Excluir',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (isOccurrenceCancel) {
        await _taskService.cancelOccurrence(task.id!, _selectedDate);
      } else {
        await _taskService.deleteTask(task.id!);
      }
      _loadTasks(query: _searchQuery);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isOccurrenceCancel
                  ? 'Ocorrência excluída.'
                  : 'Tarefa excluída.',
            ),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _toggleTask(Task task, bool completed) async {
    await _taskService.toggleTaskCompleted(
      task: task,
      completed: completed,
      date: _selectedDate,
    );
    _loadTasks(query: _searchQuery);
  }

  Future<void> _toggleSubtask(Task task, int subtaskIndex) async {
    final sub = task.subtasks[subtaskIndex];
    await _taskService.toggleSubtaskCompleted(
      sub.id!,
      _selectedDate,
      !sub.completed,
      isRecurring: task.isRecurring,
    );
    _loadTasks(query: _searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _searchQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.accent],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.checklist_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            const Text('App Task'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Arquivadas',
            onPressed: _openArchived,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(isSearching ? 64 : 168),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Pesquisar tarefas...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.textSecondary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadTasks();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              if (!isSearching) ...[
                _buildWeekNavigation(),
                _buildWeekdaySelector(),
              ],
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : _tasks.isEmpty
              ? EmptyState(isSearching: isSearching)
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: () => _loadTasks(query: _searchQuery),
                  child: Column(
                    children: [
                      if (!isSearching) _buildStatsBar(),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 100),
                          itemCount: _tasks.length,
                          itemBuilder: (_, i) {
                            final task = _tasks[i];
                            return TaskTile(
                              task: task,
                              onEdit: () => _openForm(task: task),
                              onDelete: () => _confirmDelete(task),
                              onToggleCompleted: (val) =>
                                  _toggleTask(task, val),
                              onToggleSubtask: (idx) =>
                                  _toggleSubtask(task, idx),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text(
          'Adicionar Tarefa',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildWeekNavigation() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Semana anterior',
            onPressed: () => _changeWeek(-1),
          ),
          Expanded(
            child: Text(
              WeekdayUtils.formatWeekRange(_selectedWeekStart),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Próxima semana',
            onPressed: () => _changeWeek(1),
          ),
          TextButton(
            onPressed: _goToToday,
            child: const Text(
              'Hoje',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdaySelector() {
    final today = DateTime.now();
    final todayStr = WeekdayUtils.toDateString(today);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: List.generate(7, (i) {
          final weekday = i + 1;
          final date = WeekdayUtils.dateInWeek(_selectedWeekStart, weekday);
          final dateStr = WeekdayUtils.toDateString(date);
          final selected = _selectedWeekday == weekday;
          final isToday = dateStr == todayStr;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Material(
                color: selected
                    ? AppTheme.primary
                    : isToday
                        ? AppTheme.primary.withOpacity(0.08)
                        : AppTheme.background,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() => _selectedWeekday = weekday);
                    _loadTasks(query: _searchQuery);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          WeekdayUtils.shortLabels[i],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected || isToday
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? Colors.white
                                : isToday
                                    ? AppTheme.primary
                                    : AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          WeekdayUtils.dayNumber(date),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? Colors.white
                                : isToday
                                    ? AppTheme.primary
                                    : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStatsBar() {
    final total = _tasks.length;
    final done = _tasks.where((t) => t.completed).length;
    final pending = total - done;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          _stat('Total', total.toString(), AppTheme.primary),
          _divider(),
          _stat('Pendentes', pending.toString(), AppTheme.accent),
          _divider(),
          _stat('Concluídas', done.toString(), AppTheme.success),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 32,
      color: AppTheme.border,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
