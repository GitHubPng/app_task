# Lembretes (notificações) — Design

Data: 2026-10-19 · Status: aprovado em conversa, aguardando revisão do spec

## Contexto e objetivo

Uso pessoal diário (e de uma amiga). Depois do intervalo de horário, o próximo passo é o app
**avisar** antes das tarefas que importam, para ajudar a cumprir a rotina.

**Sucesso:** marcar "Treino" com lembrete 15 min antes e receber a notificação às 14:45 nos dias
em que o Treino acontece — e não receber em dia cancelado, com tarefa já concluída ou no horário
antigo quando aquele dia foi alterado.

2º de 3 itens priorizados (intervalo → **lembretes** → estatísticas).

## Decisões

| # | Decisão | Origem |
|---|---------|--------|
| D1 | Lembrete **só nas tarefas marcadas**; desligado por padrão | usuário |
| D2 | Antecedência por tarefa: 0, 5, 15, 30 ou 60 min (padrão 15 ao ligar) | usuário |
| D3 | Notificação só informa; **tocar abre o app**. Sem botões de ação | usuário |
| D4 | Configuração **por tarefa** (não por versão de regra nem por data); dispara pelo início **efetivo** do dia | suposição aprovada |
| D5 | **Janela de 14 dias** recalculada inteira (cancela tudo + agenda) | usuário |
| D6 | Sem aviso para ocorrência cancelada, já concluída, sem início ou com horário de aviso no passado | aprovado (Parte 1) |
| D7 | `flutter_local_notifications` **17.2.4** (compileSdk 34) + `timezone` ^0.9; **sem** `flutter_timezone` | aprovado (Parte 2) |
| D8 | CI roda `flutter test` + build também em **pull requests** | aprovado (Parte 2) |

Fora de escopo: ações na notificação (Concluir/Adiar), aviso no fim/pausa, chave global,
atualização em segundo plano sem abrir o app, publicação na Play Store.

## Dados (banco v7)

`tasks` ganha:

| Coluna | Tipo | Default |
|--------|------|---------|
| `reminder_enabled` | `INTEGER NOT NULL` | `0` |
| `reminder_minutes_before` | `INTEGER` | `NULL` (o app usa 15 quando ligado sem valor) |

- `DatabaseHelper.schemaVersion` = 7; `onUpgrade` (`oldVersion < 7`) só adiciona colunas.
- `Task` ganha `bool reminderEnabled` e `int? reminderMinutesBefore` (mapa/`copyWith`).
- `kReminderOptions = [0, 5, 15, 30, 60]`.
- Backup: aceita `dbVersion` 5–7; em backups antigos o lembrete fica desligado (default da coluna).
  Colunas ausentes no JSON simplesmente não entram no `INSERT`.

## Planejamento (lógica pura — `lib/services/reminder_planner.dart`)

```
class PlannedReminder { int id; DateTime fireAt; String title; String body; String date; }
List<PlannedReminder> planReminders(Map<DateTime, List<Task>> tasksByDay, DateTime now)
```

- Entrada: tarefas **efetivas** de cada dia da janela (as que `getTasksForDate` já devolve —
  canceladas não aparecem; `completed` já é o do dia).
- Para cada tarefa com `reminderEnabled` e `effectiveTime` válido:
  `fireAt = dia + início efetivo − (reminderMinutesBefore ?? 15) min`.
- Descarta: `completed`, `fireAt <= now`.
- `id` estável e único por (tarefa, data): `taskId * 10000 + (dias desde 2020-01-01) % 10000`
  (cabe em int32 enquanto `taskId < 214748`).
- Texto: título = `effectiveTitle`; corpo = `"Começa às HH:mm (em N min)"`, ou
  `"Começa agora"` com antecedência 0; com fim, acrescenta `" · HH:mm–HH:mm"` via
  `TimeRange.label`.
- Janela: hoje + 13 dias (14 datas). Limite do Android (500 pendentes) folgado (~110 no pior caso
  realista).

## Agendamento (`lib/services/notification_service.dart`)

Casca fina sobre o plugin, sem lógica de negócio:

- `init()` — inicializa plugin e canal `lembretes` ("Lembretes de tarefas", importância alta).
- `Future<bool> requestPermission()` — Android 13+ `POST_NOTIFICATIONS`.
- `Future<void> replaceAll(List<PlannedReminder>)` — `cancelAll()` + `zonedSchedule` de cada um,
  `AndroidScheduleMode.exactAllowWhileIdle`, horário convertido com
  `tz.TZDateTime.from(fireAt.toUtc(), tz.UTC)` (instante absoluto; respeita o fuso do aparelho).
- Tocar na notificação abre o app (comportamento padrão; home já abre no dia de hoje).

`TaskService.syncReminders({DateTime? now})` monta `tasksByDay` (14 dias), chama
`planReminders` e entrega a um `ReminderScheduler` injetável (interface com `replaceAll`), para
testar sem plugin. Chamado:

- ao abrir o app (após splash);
- após salvar/criar, excluir tarefa ou ocorrência, concluir/desmarcar, editar ocorrência/rotina,
  importar backup.

Falha no agendamento nunca quebra o fluxo do usuário: erro é engolido e logado (`debugPrint`).

## Android

`AndroidManifest.xml` do app:

- `<uses-permission>`: `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `USE_EXACT_ALARM`.
- Receivers do plugin: `ScheduledNotificationReceiver` e `ScheduledNotificationBootReceiver`
  (com `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, `QUICKBOOT_POWERON`) — restauram avisos após
  reiniciar/atualizar.

`android/app/build.gradle`: `coreLibraryDesugaringEnabled true` e
`coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:1.2.2'` (exigido pelo plugin).

Limitação conhecida (documentar no README): fabricantes com otimização agressiva de bateria
podem atrasar/suprimir; solução é remover o app da otimização de bateria.

## Telas

- **Formulário** (criar/editar/editar rotina; não em "editar esta ocorrência"): abaixo do bloco
  Horário, `SwitchListTile` "Lembrete", visível só com início definido. Ligado → seletor
  "Na hora / 5 / 15 / 30 min / 1 h antes". Limpar o início desliga o lembrete.
  Ao ligar: pede permissão; negada → volta para desligado + snack
  "Permita notificações nas configurações do Android para receber lembretes."
- **Card**: ícone `notifications_active_outlined` no chip de horário quando o lembrete está ligado.

## CI

`.github/workflows/build.yml`: gatilhos `push` em `master` **e** `pull_request` para `master`;
passos `flutter test` antes do build. Upload do APK continua.

## Testes

- `reminder_planner_test.dart`: antecedência (0/15/60), padrão 15 com valor nulo, aviso no
  passado descartado, concluída descartada, sem início descartada, lembrete desligado descartado,
  override de horário do dia usado, corpo com e sem fim, ids estáveis e distintos entre datas e
  tarefas.
- `syncReminders` com scheduler falso: janela de 14 dias, ocorrência cancelada não agenda,
  concluir remove o aviso do dia.
- Migração v6 → v7; backup v5/v6 importa com lembrete desligado; roundtrip v7 preserva.
- Plugin/permissões: sem teste automatizado; validação no aparelho.
