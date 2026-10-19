import 'dart:io';

import 'package:app_task/database/database_helper.dart';
import 'package:app_task/models/task.dart';
import 'package:app_task/services/reminder_planner.dart';
import 'package:app_task/services/reminder_scheduler.dart';
import 'package:app_task/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

class FakeScheduler implements ReminderScheduler {
  List<PlannedReminder>? last;
  bool fail = false;

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    if (fail) throw Exception('plugin indisponível');
    last = reminders;
  }
}

void main() {
  setUpAll(() {
    initTestDatabase();
  });

  late Directory dir;
  late DatabaseHelper db;
  late FakeScheduler scheduler;
  late TaskService service;
  late int treinoId;
  final now = DateTime(2026, 8, 31, 6);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('app_task_reminders_');
    db = DatabaseHelper.test('${dir.path}/r.db');
    scheduler = FakeScheduler();
    service = TaskService(db: db, scheduler: scheduler);
    treinoId = await service.createTask(
      Task(
        title: 'Treino',
        createdAt: '2026-01-01T00:00:00.000',
        isRecurring: true,
        recurringDays: '1,3,5',
        time: '15:00',
        reminderEnabled: true,
        reminderMinutesBefore: 15,
      ),
      [],
    );
    await service.createTask(
      Task(
        title: 'Escola',
        createdAt: '2026-01-01T00:00:00.000',
        isRecurring: true,
        recurringDays: '1,2,3,4,5',
        time: '19:00',
      ),
      [],
    );
  });

  tearDown(() async {
    await db.closeForTest();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  List<DateTime> fireDays() => scheduler.last!
      .map((r) => DateTime(r.fireAt.year, r.fireAt.month, r.fireAt.day))
      .toList();

  test('agenda 14 dias só das tarefas com lembrete', () async {
    final result = await service.syncReminders(now: now);
    expect(result, same(scheduler.last));
    // seg/qua/sex entre 31/08 e 13/09 → 6 avisos, todos do Treino.
    expect(scheduler.last!.length, 6);
    expect(scheduler.last!.every((r) => r.title == 'Treino'), isTrue);
    expect(fireDays().first, DateTime(2026, 8, 31));
    expect(fireDays().last, DateTime(2026, 9, 11));
  });

  test('ocorrência cancelada não agenda', () async {
    await service.cancelOccurrence(treinoId, DateTime(2026, 9, 2));
    await service.syncReminders(now: now);
    expect(scheduler.last!.length, 5);
    expect(fireDays(), isNot(contains(DateTime(2026, 9, 2))));
  });

  test('concluir remove o aviso do dia', () async {
    final task = (await db.getTaskById(treinoId))!;
    await service.toggleTaskCompleted(
      task: task,
      completed: true,
      date: DateTime(2026, 8, 31),
    );
    await service.syncReminders(now: now);
    expect(fireDays(), isNot(contains(DateTime(2026, 8, 31))));
  });

  test('falha do agendador não quebra o fluxo', () async {
    scheduler.fail = true;
    final result = await service.syncReminders(now: now);
    expect(result.length, 6);
  });
}
