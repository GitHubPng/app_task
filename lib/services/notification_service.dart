import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'reminder_planner.dart';
import 'reminder_scheduler.dart';

/// Casca fina sobre flutter_local_notifications; sem regra de negócio.
class NotificationService implements ReminderScheduler {
  static final instance = NotificationService._();

  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'lembretes',
      'Lembretes de tarefas',
      channelDescription: 'Avisos antes das tarefas com lembrete ligado',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> init() async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  /// Android 13+: pede POST_NOTIFICATIONS. Versões antigas: já concedida.
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    await _plugin.cancelAll();
    for (final r in reminders) {
      try {
        await _schedule(r, AndroidScheduleMode.exactAllowWhileIdle);
      } on PlatformException {
        // Sem permissão de alarme exato: aviso aproximado em vez de nenhum.
        await _schedule(r, AndroidScheduleMode.inexactAllowWhileIdle);
      }
    }
  }

  Future<void> _schedule(PlannedReminder r, AndroidScheduleMode mode) {
    return _plugin.zonedSchedule(
      r.id,
      r.title,
      r.body,
      // Instante absoluto: a conversão para UTC usa o fuso do aparelho.
      tz.TZDateTime.from(r.fireAt.toUtc(), tz.UTC),
      _details,
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
