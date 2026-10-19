# Lembretes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Notificação antes das tarefas marcadas, agendada para os próximos 14 dias, com o próximo aviso visível na home.

**Architecture:** Planejamento puro (`reminder_planner.dart`) transforma tarefas efetivas por dia em `PlannedReminder`s; `TaskService.syncReminders` monta a janela e entrega a um `ReminderScheduler` (interface); `NotificationService` implementa a interface com `flutter_local_notifications`. A home dispara o sync no início e após mutações.

**Tech Stack:** Flutter 3.22.0, sqflite, flutter_local_notifications 17.2.4, timezone ^0.9.

**Spec:** `docs/superpowers/specs/2026-10-19-lembretes-design.md`

## Global Constraints

- `kReminderOptions = [0, 5, 15, 30, 60]`; padrão 15 quando `reminderMinutesBefore` é nulo.
- Janela: hoje + 13 dias (14 datas).
- `DatabaseHelper.schemaVersion` = 7; backup aceita 5–7.
- Plugin `flutter_local_notifications: 17.2.4` (exato) e `timezone: ^0.9.0`; sem `flutter_timezone`.
- Erro de agendamento nunca quebra o fluxo do usuário.
- Versão `1.3.0+4`.

## Review Focus

1. Concluir a tarefa antes do aviso → aviso do dia some (Task 3: teste com scheduler falso).
2. Ocorrência cancelada / horário alterado só naquele dia → sem aviso / aviso no horário novo (Task 3).
3. Lembrete ligado mas início removido no formulário → lembrete desligado ao salvar (Task 5: `_clearStart` zera `_reminderEnabled`).
4. Permissão negada → interruptor volta para desligado e snack explicativo (Task 5).
5. Testes de serviço sem plugin → `TaskService(db:)` não instancia o plugin enquanto `syncReminders` não é chamado (Task 3: scheduler injetado/lazy).

---

### Task 1: Banco v7, modelo e backup

**Files:** Modify `lib/database/database_helper.dart`, `lib/models/task.dart`, `lib/services/backup_service.dart`; Tests `test/time_range_db_test.dart` (migração), `test/backup_service_test.dart`, `test/migration_v3_test.dart` (versão 7)

**Interfaces — Produces:** `Task.reminderEnabled` (bool, default false), `Task.reminderMinutesBefore` (int?); colunas `reminder_enabled INTEGER NOT NULL DEFAULT 0`, `reminder_minutes_before INTEGER`; `schemaVersion = 7`.

- [ ] **Step 1: Testes** — migração para v7 cria as 2 colunas, `user_version` 7, tarefas existentes com `reminder_enabled = 0`; roundtrip de backup preserva lembrete; backup v6 (sem colunas de lembrete) importa com lembrete desligado; `dbVersion` 8 recusado (ajustar o teste "7 recusado" → 8).
- [ ] **Step 2:** FAIL. **Step 3:** implementar (`toMap` usa `1/0`; `fromMap` trata nulo como false). **Step 4:** suíte PASS. **Step 5:** commit.

### Task 2: Planejador puro

**Files:** Create `lib/services/reminder_planner.dart`; Test `test/reminder_planner_test.dart`

**Interfaces — Produces:**
- `const kReminderOptions = [0, 5, 15, 30, 60]; const kDefaultReminderMinutes = 15;`
- `class PlannedReminder { final int id; final DateTime fireAt; final String title; final String body; }`
- `int reminderId(int taskId, DateTime day)` = `taskId * 10000 + daysSince(2020-01-01) % 10000`
- `List<PlannedReminder> planReminders(Map<DateTime, List<Task>> tasksByDay, DateTime now)` — ordenado por `fireAt`
- `PlannedReminder? nextReminder(List<PlannedReminder> planned, DateTime now)`

- [ ] **Step 1: Testes** — Treino 15:00, 15 min → `fireAt` 14:45, corpo `"Começa às 15:00 (em 15 min)"`; 0 min → `"Começa agora"`; nulo → 15; com fim 08–15 → corpo termina com `" · 08:00–15:00"`; `fireAt <= now` descartado; `completed` descartado; sem início descartado; `reminderEnabled == false` descartado; override de horário do dia (`occurrenceTimeOverride = '17:00'`) → 16:45; ids distintos para (mesma tarefa, dias diferentes) e (tarefas diferentes, mesmo dia), e estáveis entre chamadas; `nextReminder` ignora passados e pega o mais cedo; lista vazia → `null`.
- [ ] **Step 2:** FAIL. **Step 3:** implementar. **Step 4:** PASS. **Step 5:** commit.

### Task 3: `syncReminders`

**Files:** Modify `lib/services/task_service.dart`; Create `lib/services/reminder_scheduler.dart`; Test `test/reminder_sync_test.dart`

**Interfaces:**
- Consumes: `planReminders`, `PlannedReminder` (Task 2).
- Produces:
  - `abstract class ReminderScheduler { Future<void> replaceAll(List<PlannedReminder> reminders); }`
  - `TaskService({DatabaseHelper? db, ReminderScheduler? scheduler})`; scheduler padrão obtido só dentro de `syncReminders` (`NotificationService.instance`).
  - `Future<List<PlannedReminder>> syncReminders({DateTime? now})` — devolve o que foi entregue; captura exceção do scheduler (`debugPrint`) e devolve a lista mesmo assim.

- [ ] **Step 1: Testes** (scheduler falso que guarda a última lista; `now = 2026-08-31 06:00`) — Treino seg/qua/sex 15:00 com lembrete 15 → 6 avisos na janela (31/08–13/09); cancelar 02/09 → 5; concluir 31/08 → aviso de 31/08 some; tarefa sem lembrete não entra; scheduler que lança exceção → `syncReminders` não lança.
- [ ] **Step 2:** FAIL. **Step 3:** implementar. **Step 4:** PASS. **Step 5:** commit.

### Task 4: Plugin, Android, CI e versão

**Files:** Create `lib/services/notification_service.dart`; Modify `pubspec.yaml`, `pubspec.lock`, `android/app/build.gradle`, `android/app/src/main/AndroidManifest.xml`, `.github/workflows/build.yml`

**Interfaces — Produces:** `class NotificationService implements ReminderScheduler { static final instance; Future<void> init(); Future<bool> requestPermission(); Future<void> replaceAll(...); }` — canal `lembretes` / "Lembretes de tarefas", importância alta; `zonedSchedule` com `tz.TZDateTime.from(fireAt.toUtc(), tz.UTC)`, `AndroidScheduleMode.exactAllowWhileIdle`, `uiLocalNotificationDateInterpretation: absoluteTime`.

- [ ] **Step 1:** `flutter pub add flutter_local_notifications:17.2.4 timezone:^0.9.0`; versão `1.3.0+4`.
- [ ] **Step 2:** `build.gradle`: `compileOptions { coreLibraryDesugaringEnabled true }`, dependência `coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:1.2.2'`. Manifest: permissões `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `USE_EXACT_ALARM`; receivers `com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver` e `...ScheduledNotificationBootReceiver` (ações `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, `QUICKBOOT_POWERON`, `com.htc.intent.action.QUICKBOOT_POWERON`), ambos `exported="false"`.
- [ ] **Step 3:** CI: gatilho `pull_request: branches: [master]`; passo `flutter test` antes do build.
- [ ] **Step 4:** `flutter analyze` sem issues; `flutter test` verde. **Step 5:** commit.

### Task 5: Telas

**Files:** Modify `lib/main.dart`, `lib/screens/task_form_screen.dart`, `lib/widgets/task_tile.dart`, `lib/screens/home_screen.dart`, `README.md`

- [ ] **Step 1:** `main()`: `await NotificationService.instance.init()` (try/catch) antes de `runApp`.
- [ ] **Step 2:** Formulário (não em edição de ocorrência; visível só com início): `SwitchListTile` "Lembrete"; ligado → `DropdownButtonFormField<int>` com rótulos "Na hora", "5 min antes", "15 min antes", "30 min antes", "1 h antes". Ao ligar: `requestPermission()`; falso → desliga e snack "Permita notificações nas configurações do Android para receber lembretes.". `_clearStart` desliga. Gravação: `createTask`/`updateTask` via campos de `Task`; `updateRecurrenceRule`/`convertToRecurring` ganham `bool? reminderEnabled, int? reminderMinutesBefore` gravados em `tasks`.
- [ ] **Step 3:** Card: ícone `notifications_active_outlined` (tamanho 11) antes do chip de horário quando `reminderEnabled`.
- [ ] **Step 4:** Home: `_reminders` (lista); `_syncReminders()` chama `syncReminders()` e guarda; chamado no `initState` e após cada mutação (form `true`, excluir, concluir/desmarcar tarefa, importar). Linha "Próximo aviso: {título} às {HH:mm} · {Seg} {dd/MM}" acima da lista, via `nextReminder(_reminders, DateTime.now())`, oculta na busca/sem aviso.
- [ ] **Step 5:** README: RF15 lembretes, RF16 próximo aviso, banco v7, limitação de bateria.
- [ ] **Step 6:** `flutter analyze` sem issues; `flutter test` verde; commit e push.
