# Estatísticas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tela de estatísticas com % cumprido da semana atual e das 8 últimas.

**Architecture:** Cálculo puro em `stats.dart` sobre tarefas efetivas por dia; `TaskService.weeklyStats` monta os dias via `getTasksForDate`; `StatsScreen` exibe.

**Tech Stack:** Flutter 3.22.0, sqflite.

**Spec:** `docs/superpowers/specs/2026-10-20-estatisticas-design.md`

## Global Constraints

- 8 semanas, segunda–domingo; dias após hoje não contam; semana vazia → "sem dados".
- Sem dependência nova.

## Review Focus

1. Segunda-feira de manhã com nada feito → 0% da semana atual (não "sem dados") se há tarefas hoje (Task 1: dia de hoje conta).
2. Semana antes do uso do app → "sem dados" (Task 1).
3. Ocorrência cancelada não infla o total (Task 2).
4. Tela não trava a home: cálculo assíncrono com loading (Task 3).
5. Delta só com as duas semanas com dados (Task 1).

---

### Task 1: Cálculo puro

**Files:** Create `lib/services/stats.dart`; Test `test/stats_test.dart`

**Produces:** `WeekStats`, `computeWeekStats(...)`, `weekDelta(...)` (assinaturas no spec).

- [ ] Testes: hoje = qua 02/09/2026; tarefas seg (1 de 2 feitas), ter (2 de 2), qua (0 de 1), qui (1 tarefa, futura) → semana atual total 5, done 3, rate 0.6; semana anterior sem tarefas → `rate` nulo; 8 itens, `[0].weekStart` = 31/08; `weekDelta` 0.6 vs 0.5 → 10, 0.4 vs 0.5 → −10, com nulo → `null`.
- [ ] FAIL → implementar → PASS → commit.

### Task 2: `weeklyStats`

**Files:** Modify `lib/services/task_service.dart`; Test `test/stats_test.dart`

- [ ] Testes (banco de teste): Treino seg/qua/sex, 31/08 feito, 02/09 cancelado, hoje = sex 04/09 → semana atual total 2 (31/08 e 04/09), done 1; avulsa em 03/09 conta; regra muda para ter/qui a partir de 08/09 não altera a semana de 31/08.
- [ ] FAIL → implementar → PASS → commit.

### Task 3: Tela

**Files:** Create `lib/screens/stats_screen.dart`; Modify `lib/screens/home_screen.dart`, `README.md`

- [ ] `StatsScreen` conforme spec; ícone na AppBar da home antes do menu de backup.
- [ ] README: RF17 estatísticas semanais.
- [ ] `flutter analyze` sem issues; `flutter test` verde; commit e push.
