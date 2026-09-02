import 'package:flutter/material.dart';
import '../models/task.dart';
import '../utils/app_theme.dart';
import '../utils/validators.dart';
import '../utils/weekday_utils.dart';
import 'subtask_widget.dart';

class TaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onToggleCompleted;
  final ValueChanged<int>? onToggleSubtask;

  /// Modo somente leitura (tela Arquivadas).
  final bool readOnly;

  const TaskTile({
    super.key,
    required this.task,
    this.onEdit,
    this.onDelete,
    this.onToggleCompleted,
    this.onToggleSubtask,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final completedSubtasks = task.subtasks.where((s) => s.completed).length;
    final totalSubtasks = task.subtasks.length;
    final canToggle = !readOnly && onToggleCompleted != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: task.completed
              ? AppTheme.border
              : AppTheme.primary.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: 1.1,
                  child: Checkbox(
                    value: task.completed,
                    onChanged: canToggle
                        ? (val) => onToggleCompleted!(val ?? false)
                        : null,
                    activeColor: AppTheme.success,
                    shape: const CircleBorder(),
                    side: BorderSide(
                      color: task.completed
                          ? AppTheme.success
                          : AppTheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.effectiveTitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: task.completed
                              ? AppTheme.completedText
                              : AppTheme.textPrimary,
                          decoration: task.completed
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildMetaRow(),
                    ],
                  ),
                ),
                if (!readOnly) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: AppTheme.primary,
                    onPressed: onEdit,
                    tooltip: 'Editar',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: AppTheme.danger,
                    onPressed: onDelete,
                    tooltip: 'Excluir',
                  ),
                ],
              ],
            ),
          ),
          if (task.effectiveDescription != null &&
              task.effectiveDescription!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
              child: Text(
                task.effectiveDescription!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (task.subtasks.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalSubtasks > 0
                            ? completedSubtasks / totalSubtasks
                            : 0,
                        backgroundColor: AppTheme.border,
                        color: AppTheme.success,
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$completedSubtasks/$totalSubtasks',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: task.subtasks.asMap().entries.map((entry) {
                  final index = entry.key;
                  final sub = entry.value;
                  return SubtaskWidget(
                    subtask: sub,
                    onToggle: (!readOnly && onToggleSubtask != null)
                        ? () => onToggleSubtask!(index)
                        : null,
                  );
                }).toList(),
              ),
            ),
          ] else
            const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildMetaRow() {
    final chips = <Widget>[];

    final time = task.effectiveTime;
    if (time != null && time.isNotEmpty) {
      chips.add(_metaChip(Icons.schedule_rounded, time));
    }

    if (task.isRecurring) {
      final days = task.recurringDaysList
          .map(WeekdayUtils.shortLabel)
          .where((s) => s.isNotEmpty)
          .join(' · ');
      if (days.isNotEmpty) {
        chips.add(_metaChip(Icons.repeat_rounded, days));
      }
      if (task.isOccurrenceOverride) {
        chips.add(_metaChip(Icons.tune_rounded, 'Alterada'));
      }
    } else if (task.dueDate != null && task.dueDate!.isNotEmpty) {
      chips.add(
        _metaChip(
          Icons.calendar_today_rounded,
          Validators.formatDateDisplay(task.dueDate),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: chips,
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
