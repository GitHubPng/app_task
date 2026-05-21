import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../utils/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/task_tile.dart';
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

  @override
  void initState() {
    super.initState();
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
    final tasks = await _taskService.getAllTasks(
      searchQuery: query?.isNotEmpty == true ? query : null,
    );
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });
  }

  Future<void> _openForm({Task? task}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(task: task),
        fullscreenDialog: true,
      ),
    );
    if (result == true) _loadTasks(query: _searchQuery);
  }

  Future<void> _confirmDelete(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Excluir tarefa?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'A tarefa "${task.title}" será removida permanentemente. Esta ação não pode ser desfeita.',
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
            child: const Text(
              'Excluir',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _taskService.deleteTask(task.id!);
      _loadTasks(query: _searchQuery);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Tarefa excluída.'),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _toggleTask(Task task, bool completed) async {
    await _taskService.toggleTaskCompleted(task.id!, completed);
    _loadTasks(query: _searchQuery);
  }

  Future<void> _toggleSubtask(Task task, int subtaskIndex) async {
    final sub = task.subtasks[subtaskIndex];
    await _taskService.toggleSubtaskCompleted(sub.id!, !sub.completed);
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
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
                      // Stats bar
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
