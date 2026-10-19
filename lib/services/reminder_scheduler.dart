import 'reminder_planner.dart';

/// Quem entrega os avisos ao sistema (plugin em produção, falso nos testes).
abstract class ReminderScheduler {
  /// Substitui todos os avisos agendados pelo app por [reminders].
  Future<void> replaceAll(List<PlannedReminder> reminders);
}
