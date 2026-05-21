import 'package:flutter/material.dart';
import '../models/subtask.dart';
import '../utils/app_theme.dart';

class SubtaskWidget extends StatelessWidget {
  final Subtask subtask;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  const SubtaskWidget({
    super.key,
    required this.subtask,
    this.onToggle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: subtask.completed,
            onChanged: onToggle != null ? (_) => onToggle!() : null,
            activeColor: AppTheme.success,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: const BorderSide(color: AppTheme.border, width: 1.5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            subtask.title,
            style: TextStyle(
              fontSize: 13,
              color: subtask.completed
                  ? AppTheme.completedText
                  : AppTheme.textPrimary,
              decoration: subtask.completed
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
            ),
          ),
        ),
        if (onDelete != null)
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            color: AppTheme.textSecondary,
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
      ],
    );
  }
}
