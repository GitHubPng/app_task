# Intervalo de horário Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tarefas com fim opcional e uma pausa opcional, destaque "Agora"/"Pausa" e aviso de sobreposição.

**Architecture:** Lógica pura de horários em `lib/utils/time_range.dart`; três colunas novas (`end_time`, `break_start`, `break_end`) em `tasks`, `task_recurrence_rules` e `task_occurrences` (banco v6), propagadas pelo mesmo esquema de override/regra que `time` já usa; service expõe `findConflicts`; UI consome.

**Tech Stack:** Flutter 3.22.0 / Dart 3.4, sqflite, flutter_test + sqflite_common_ffi.

**Spec:** `docs/superpowers/specs/2026-10-19-intervalo-de-horario-design.md`

## Global Constraints

- Horários no formato `HH:mm`; colunas `TEXT` nulas.
- Override de ocorrência: `null` = herda da regra; `''` = removido nesta data.
- `DatabaseHelper.schemaVersion` = 6; migração só adiciona colunas.
- Backup importa `dbVersion` de 5 até `schemaVersion`; maior é recusado.
- Fim no mesmo dia; uma pausa; sem fim nunca é "Agora"; dentro da pausa não conflita.
- `flutter analyze` sem issues e `flutter test` verde ao fim de cada task.

## Review Focus

1. Ocorrência que encurta o fim e deixa a pausa da regra fora do período → erro claro, nada gravado (Task 5 valida pelo efetivo; teste de `validate` cobre a combinação).
2. Rotina antiga (sem fim) após upgrade → continua aparecendo e ordenando por início (teste de migração em Task 2).
3. Backup v5 real (`app_task_backup_rotina.json`, sem as colunas) → importa com campos nulos (Task 4).
4. Editar rotina sem tocar no horário não apaga fim/pausa existentes (Task 3: `updateRecurrenceRule` recebe e grava os 3 campos vindos do form).
5. Limite exato: 15:00 com fim 15:00 não é "Agora"; 12:00 com pausa 12–13 é "Pausa" (Task 1).

---

### Task 1: Lógica pura de horários

**Files:**
- Create: `lib/utils/time_range.dart`
- Test: `test/time_range_test.dart`

**Interfaces:**
- Produces:
  - `enum TimeStatus { none, now, paused }`
  - `class TimeRange { final String? start, end, breakStart, breakEnd; const TimeRange({...}); bool get hasEnd; }`
  - `String? TimeRange.validate()` — mensagem pt-BR ou `null`
  - `TimeStatus TimeRange.statusAt(int minuteOfDay)`
  - `bool TimeRange.conflictsWith(TimeRange other)`
  - `static int? TimeRange.toMinutes(String? hhmm)` (`null`/`''`/inválido → `null`)

- [ ] **Step 1: Testes** — `validate`: válido `08:00–15:00` pausa `12:00–13:00` → `null`; fim sem início → "Defina o início antes do fim."; fim ≤ início → "O fim deve ser depois do início."; pausa sem fim → "Pausa exige horário de fim."; pausa incompleta → "Defina início e fim da pausa."; pausa fora/invertida → "A pausa deve ficar dentro do período.". `statusAt`: 07:59 none, 08:00 now, 12:00 paused, 12:59 paused, 13:00 now, 14:59 now, 15:00 none; sem fim → none. `conflictsWith`: Trabalho 08–15 p12–13 × Acordar 05:50 → false; × ponto 12:00 → false; × ponto 14:00 → true; × 12:15–12:45 → false; × 11:30–12:30 → true; dois pontos iguais → false; sem início → false.
- [ ] **Step 2:** `flutter test test/time_range_test.dart` → FAIL (arquivo inexistente).
- [ ] **Step 3:** Implementar. Parte ativa = `[start,end)` menos `[breakStart,breakEnd)`; ponto `p` conflita se `start ≤ p < end` e fora da pausa; intervalos conflitam se algum segmento ativo de um intercepta algum do outro.
- [ ] **Step 4:** teste PASS.
- [ ] **Step 5:** commit.

### Task 2: Banco v6, modelos e hidratação

**Files:**
- Modify: `lib/database/database_helper.dart`, `lib/models/task.dart`, `lib/models/task_recurrence_rule.dart`, `lib/models/task_occurrence.dart`
- Test: `test/time_range_db_test.dart`

**Interfaces:**
- Produces:
  - `DatabaseHelper.schemaVersion == 6`
  - `Task`: `endTime`, `breakStart`, `breakEnd`; runtime `ruleEndTimeForDate`, `ruleBreakStartForDate`, `ruleBreakEndForDate`, `occurrenceEndTimeOverride`, `occurrenceBreakStartOverride`, `occurrenceBreakEndOverride`; getters `effectiveEndTime`, `effectiveBreakStart`, `effectiveBreakEnd`; `TimeRange get effectiveRange`. `copyWith` aceita os 3 campos + `clearEndTime`/`clearBreak`.
  - `TaskRecurrenceRule`/`TaskOccurrence`: `endTime`, `breakStart`, `breakEnd`.
  - `upsertRecurrenceRule(..., String? endTime, String? breakStart, String? breakEnd)` e `upsertOccurrence(...)` idem; `upsertOccurrence` não cria linha se todos os 6 overrides forem `null`; `isOccurrenceOverride` considera os 6.

- [ ] **Step 1: Testes** — migração de fixture v5 (criada via `createV2DatabaseFixture` + abertura) para v6: `user_version` 6, colunas existem nas 3 tabelas, dados preservados; tarefa recorrente sem fim continua aparecendo. Atualizar `migration_v3_test.dart` (versão esperada 6).
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** Colunas em `onCreate`; bloco `oldVersion < 6` com `_addColumnIfMissing`; `toMap`/`fromMap`; `_applyRuleToTask` e `_applyOccurrenceAndCompletions` copiam os campos.
- [ ] **Step 4:** suíte inteira PASS.
- [ ] **Step 5:** commit.

### Task 3: Service — propagação e conflitos

**Files:**
- Modify: `lib/services/task_service.dart`
- Test: `test/time_range_db_test.dart`

**Interfaces:**
- Consumes: Task 1 (`TimeRange`), Task 2 (campos e upserts).
- Produces:
  - `updateRecurrenceRule`, `convertToRecurring`, `updateOccurrence`: novos params `String? endTime, String? breakStart, String? breakEnd`; `createTask` lê de `Task`.
  - `Future<List<Task>> findConflicts({required TimeRange range, required List<DateTime> dates, int? excludeTaskId})` — tarefas efetivas de cada data cujo `effectiveRange.conflictsWith(range)`; ocorrência de data populada em `occurrenceDate`.
  - `static List<DateTime> datesForRule(DateTime effectiveFrom, List<int> weekdays)` — datas dos weekdays na semana de `effectiveFrom`.

- [ ] **Step 1: Testes** — regra 08–15 p12–13 criada; nova versão 09–16 a partir de 07/09/2026 → 31/08 mantém 08–15/p12–13, 07/09 tem 09–16; `updateOccurrence(end: '14:00')` só muda aquela data; `updateOccurrence(breakStart: '', breakEnd: '')` remove pausa só naquela data; `findConflicts` acha Treino 14:00 contra Trabalho 08–15 numa segunda, não acha Almoço 12:00, exclui a própria tarefa; `datesForRule(qua 02/09/2026, [1,5])` → seg 31/08 e sex 04/09.
- [ ] **Step 2:** FAIL. **Step 3:** implementar. **Step 4:** PASS. **Step 5:** commit.

### Task 4: Backup v5..v6

**Files:**
- Modify: `lib/services/backup_service.dart`
- Test: `test/backup_service_test.dart`

- [ ] **Step 1: Testes** — JSON v5 (export de banco v6 com `dbVersion` 5 e as 3 colunas removidas das linhas) importa com campos nulos; roundtrip v6 preserva `end_time`/pausa; `dbVersion` 7 recusado; 4 recusado. Ajustar teste existente "versão de banco diferente" (99 continua recusado).
- [ ] **Step 2:** FAIL. **Step 3:** aceitar `5 ≤ dbVersion ≤ schemaVersion`. **Step 4:** PASS. **Step 5:** commit.

### Task 5: Telas

**Files:**
- Modify: `lib/screens/task_form_screen.dart`, `lib/widgets/task_tile.dart`, `lib/screens/home_screen.dart`, `README.md`

**Interfaces:**
- Consumes: `TimeRange`, `TaskService.findConflicts`, `datesForRule`, params novos.
- `TaskTile` ganha `TimeStatus status` (default `none`).

- [ ] **Step 1:** Formulário: `_selectedEndTime`, `_selectedBreakStart`, `_selectedBreakEnd`; bloco progressivo (Fim após início; "+ Adicionar pausa" após fim; X remove); limpar início limpa tudo, limpar fim limpa pausa. Antes de salvar: `TimeRange(...).validate()` (snack de erro); depois `findConflicts` com datas: avulsa `[dueDate]`, ocorrência `[occurrenceDate]`, rotina `datesForRule(efetiva ou hoje, dias)`; se houver, diálogo "Conflito de horário" listando `título · horário · dd/MM` com **Voltar** / **Salvar mesmo assim**. Ocorrência grava fim/pausa via `_overrideOrNull`.
- [ ] **Step 2:** Card: chip `08:00–15:00 · pausa 12:00–13:00`; com `status != none`, borda `AppTheme.primary` largura 2 e etiqueta "Agora"/"Pausa".
- [ ] **Step 3:** Home: `Timer.periodic(1 min)` → `setState`; status calculado só se `_selectedDate` é hoje; `dispose` cancela.
- [ ] **Step 4:** README: RF/RN do intervalo, banco v6, colunas.
- [ ] **Step 5:** `flutter analyze` sem issues; `flutter test` verde. Commit e push.
