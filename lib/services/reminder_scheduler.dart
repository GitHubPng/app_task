import 'reminder_planner.dart';

/// Resultado do sync: o que de fato foi agendado, ou o erro.
class ReminderSyncResult {
  final List<PlannedReminder> scheduled;
  final Object? error;

  const ReminderSyncResult(this.scheduled, [this.error]);
}

/// Quem entrega os avisos ao sistema (plugin em produção, falso nos testes).
abstract class ReminderScheduler {
  /// Substitui todos os avisos agendados pelo app por [reminders].
  Future<void> replaceAll(List<PlannedReminder> reminders);
}
