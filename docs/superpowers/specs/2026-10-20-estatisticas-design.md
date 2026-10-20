# Estatísticas semanais — Design

Data: 2026-10-20 · Status: aprovado em conversa

## Objetivo

Responder **"estou cumprindo a rotina?"**: % cumprido na semana atual comparado às anteriores.
3º de 3 itens priorizados (intervalo → lembretes → **estatísticas**).

## Decisões

| # | Decisão | Origem |
|---|---------|--------|
| D1 | Foco em visão geral semanal (não por rotina, sem streak) | usuário |
| D2 | Conta rotinas + avulsas que aparecem em cada dia, **até hoje inclusive**; futuro não conta; canceladas não contam | usuário |
| D3 | Tela própria com semana atual + **8 semanas** | usuário |
| D4 | Calcular reusando `getTasksForDate` (mesmos números da home) | usuário |
| D5 | Semana sem tarefas = "sem dados" (não 0%) | aprovado |
| D6 | Barras simples, sem biblioteca de gráfico | aprovado |

Fora de escopo: % por rotina, sequências, gráficos, exportar estatísticas.

## Cálculo (`lib/services/stats.dart`, puro)

```
class WeekStats { DateTime weekStart; int total; int done; double? rate; }
List<WeekStats> computeWeekStats(Map<DateTime, List<Task>> tasksByDay, DateTime today, {int weeks = 8})
int? weekDelta(List<WeekStats> stats)
```

- Semanas segunda–domingo (`WeekdayUtils.weekStart`); retorno da mais recente (semana de `today`)
  para a mais antiga, sempre `weeks` itens.
- Dias com data > `today` (comparando só a data) são ignorados.
- `rate = done / total`, ou `null` se `total == 0`.
- `weekDelta`: `round((rate[0] − rate[1]) × 100)` em pontos percentuais; `null` se alguma das duas
  for `null`.

## Service

`TaskService.weeklyStats({DateTime? today, int weeks = 8})` → `Future<List<WeekStats>>`: monta
`tasksByDay` de `weekStart(today) − 7 × (weeks − 1)` até `today` com `getTasksForDate` e chama
`computeWeekStats`.

## Tela (`lib/screens/stats_screen.dart`)

- Aberta por ícone `bar_chart_rounded` na AppBar da home (tooltip "Estatísticas").
- Carregando: `CircularProgressIndicator`.
- Cartão: "Esta semana" + `72%` (ou "sem dados") + "18 de 25 tarefas" + delta
  "▲ 8 pts vs semana passada" / "▼ 3 pts…" / "= vs semana passada" (oculto se `null`).
- Lista: uma linha por semana, `dd/MM – dd/MM`, `LinearProgressIndicator` com `rate` e texto `NN%`
  ou "sem dados"; semana atual marcada "(atual)".
- Rodapé: "Conta só o que foi marcado como concluído."

## Testes

- `stats_test.dart` (puro): dia futuro ignorado; semana vazia → `rate` nulo; soma por semana;
  ordem mais recente primeiro com 8 itens; `weekDelta` positivo, negativo e nulo.
- Service: ocorrência cancelada não conta; avulsa conta na própria data; nova versão de rotina
  altera o total só a partir da vigência.
