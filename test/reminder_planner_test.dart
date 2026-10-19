import 'package:app_task/models/task.dart';
import 'package:app_task/services/reminder_planner.dart';
import 'package:flutter_test/flutter_test.dart';

Task task({
  int id = 1,
  String title = 'Treino',
  String? time = '15:00',
  String? endTime,
  bool reminder = true,
  int? minutes = 15,
  bool completed = false,
}) {
  return Task(
    id: id,
    title: title,
    createdAt: '2026-01-01T00:00:00.000',
    time: time,
    endTime: endTime,
    reminderEnabled: reminder,
    reminderMinutesBefore: minutes,
    completed: completed,
  );
}

final mon = DateTime(2026, 8, 31);
final tue = DateTime(2026, 9, 1);
final early = DateTime(2026, 8, 31, 6);

List<PlannedReminder> plan(List<Task> tasks, {DateTime? now, DateTime? day}) =>
    planReminders({day ?? mon: tasks}, now ?? early);

void main() {
  test('antecedência de 15 min', () {
    final r = plan([task()]).single;
    expect(r.fireAt, DateTime(2026, 8, 31, 14, 45));
    expect(r.title, 'Treino');
    expect(r.body, 'Começa às 15:00 (em 15 min)');
  });

  test('na hora', () {
    final r = plan([task(minutes: 0)]).single;
    expect(r.fireAt, DateTime(2026, 8, 31, 15));
    expect(r.body, 'Começa agora');
  });

  test('antecedência nula usa 15', () {
    expect(
      plan([task(minutes: null)]).single.fireAt,
      DateTime(2026, 8, 31, 14, 45),
    );
  });

  test('com fim acrescenta o período', () {
    final r = plan([
      task(title: 'Trabalho', time: '08:00', endTime: '15:00', minutes: 60),
    ]).single;
    expect(r.fireAt, DateTime(2026, 8, 31, 7));
    expect(r.body, 'Começa às 08:00 (em 60 min) · 08:00–15:00');
  });

  test('descarta passado, concluída, sem início e sem lembrete', () {
    expect(plan([task()], now: DateTime(2026, 8, 31, 14, 45)), isEmpty);
    expect(plan([task(completed: true)]), isEmpty);
    expect(plan([task(time: null)]), isEmpty);
    expect(plan([task(reminder: false)]), isEmpty);
  });

  test('usa o horário efetivo do dia', () {
    final t = task()..occurrenceTimeOverride = '17:00';
    expect(plan([t]).single.fireAt, DateTime(2026, 8, 31, 16, 45));
  });

  test('ids estáveis e distintos', () {
    final a = planReminders({
      mon: [task(), task(id: 2, title: 'Escola')],
      tue: [task()],
    }, early);
    final ids = a.map((r) => r.id).toSet();
    expect(ids.length, 3);
    expect(reminderId(1, mon), reminderId(1, mon));
    expect(reminderId(1, mon), isNot(reminderId(1, tue)));
    expect(reminderId(1, mon), isNot(reminderId(2, mon)));
  });

  test('lista ordenada por horário do aviso', () {
    final r = planReminders({
      tue: [task()],
      mon: [task(id: 2, time: '19:00')],
    }, early);
    expect(r.map((x) => x.fireAt), [
      DateTime(2026, 8, 31, 18, 45),
      DateTime(2026, 9, 1, 14, 45),
    ]);
  });

  test('nextReminder ignora passados e pega o mais cedo', () {
    final r = planReminders({
      mon: [task(), task(id: 2, time: '19:00')],
    }, early);
    expect(nextReminder(r, early)!.fireAt, DateTime(2026, 8, 31, 14, 45));
    expect(
      nextReminder(r, DateTime(2026, 8, 31, 15))!.fireAt,
      DateTime(2026, 8, 31, 18, 45),
    );
    expect(nextReminder(r, DateTime(2026, 9, 1)), isNull);
    expect(nextReminder(const [], early), isNull);
  });
}
