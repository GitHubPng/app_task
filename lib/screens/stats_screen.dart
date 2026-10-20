import 'package:flutter/material.dart';

import '../services/stats.dart';
import '../services/task_service.dart';
import '../utils/app_theme.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late final Future<List<WeekStats>> _stats = TaskService().weeklyStats();

  static String _dayMonth(DateTime d) => '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}';

  static String _percent(double? rate) =>
      rate == null ? 'sem dados' : '${(rate * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Estatísticas')),
      body: FutureBuilder<List<WeekStats>>(
        future: _stats,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Erro ao calcular: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }
          final stats = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildCurrentWeek(stats),
              const SizedBox(height: 24),
              const Text(
                'Últimas semanas',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < stats.length; i++)
                _buildWeekRow(stats[i], isCurrent: i == 0),
              const SizedBox(height: 16),
              const Text(
                'Conta só o que foi marcado como concluído.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCurrentWeek(List<WeekStats> stats) {
    final current = stats.first;
    final delta = weekDelta(stats);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Esta semana',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            _percent(current.rate),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
          Text(
            '${current.done} de ${current.total} tarefas',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          if (delta != null) ...[
            const SizedBox(height: 8),
            Text(
              delta > 0
                  ? '▲ $delta pts vs semana passada'
                  : delta < 0
                      ? '▼ ${-delta} pts vs semana passada'
                      : '= vs semana passada',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: delta > 0
                    ? AppTheme.success
                    : delta < 0
                        ? AppTheme.danger
                        : AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeekRow(WeekStats week, {required bool isCurrent}) {
    final end = week.weekStart.add(const Duration(days: 6));
    final label = '${_dayMonth(week.weekStart)} – ${_dayMonth(end)}'
        '${isCurrent ? ' (atual)' : ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: week.rate ?? 0,
                minHeight: 8,
                backgroundColor: AppTheme.border,
                color: AppTheme.success,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              _percent(week.rate),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
