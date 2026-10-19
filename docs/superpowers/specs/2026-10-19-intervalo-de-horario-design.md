# Intervalo de horário (início–fim + pausa) — Design

Data: 2026-10-19 · Status: aprovado em conversa, aguardando revisão do spec

## Contexto e objetivo

O app é usado principalmente para **rotina pessoal diária** (e por uma amiga, com a rotina dela).
Hoje cada tarefa tem só um horário pontual (`time`). Tarefas como "Trabalho" duram um período e têm
pausa (almoço), o que o app não representa.

**Sucesso:** cadastrar "Trabalho 08:00–15:00, pausa 12:00–13:00", ver no card o intervalo, ver qual
tarefa está acontecendo **agora** (ou em pausa) e ser avisado quando uma tarefa se sobrepõe a outra.

Este é o 1º de 3 itens priorizados (intervalo → lembretes → estatísticas). Lembretes e estatísticas
terão specs próprios.

## Decisões

| # | Decisão | Origem |
|---|---------|--------|
| D1 | Fim é **opcional**; tarefa sem fim continua pontual | suposição aprovada |
| D2 | Fim no **mesmo dia** (≤ 23:59); nada atravessa meia-noite | usuário |
| D3 | **Uma** pausa opcional por tarefa, só se houver fim | usuário + suposição aprovada |
| D4 | Destaque **"Agora"** / **"Pausa"** no dia de hoje | usuário |
| D5 | **Aviso** de sobreposição ao salvar, sem bloquear | usuário |
| D6 | Tarefa sem fim **nunca** fica "Agora" | aprovado (Parte 1) |
| D7 | Tarefa dentro da pausa de outra **não** conflita | aprovado (Parte 1) |
| D8 | Armazenar em **colunas novas** (não tabela de blocos, não texto) | usuário |

Fora de escopo: várias pausas, atravessar meia-noite, notificações, estatísticas.

## Dados (banco v6)

Colunas novas, todas `TEXT` nulas, formato `HH:mm`:

| Tabela | Colunas | Semântica |
|--------|---------|-----------|
| `tasks` | `end_time`, `break_start`, `break_end` | valor corrente da tarefa |
| `task_recurrence_rules` | idem | intervalo da versão da regra (vale a partir de `effective_from`) |
| `task_occurrences` | idem | override de uma data: `NULL` = herda da regra; `''` = removido nesta data |

- `DatabaseHelper.schemaVersion` = 6. `onCreate` cria as colunas; `onUpgrade` (`oldVersion < 6`) só
  as adiciona (`_addColumnIfMissing`). Nenhum dado existente muda.
- `Task` ganha os 3 campos, os campos runtime `rule*ForDate` / `occurrence*Override` correspondentes
  e os getters efetivos `effectiveEndTime`, `effectiveBreakStart`, `effectiveBreakEnd`
  (override → regra da data → `tasks`), no mesmo padrão de `effectiveTime`.
- `TaskRecurrenceRule` e `TaskOccurrence` ganham os 3 campos.
- `TaskService.updateRecurrenceRule`, `createTask`, `convertToRecurring` e `updateOccurrence`
  recebem/propagam os 3 campos; `upsertRecurrenceRule` e `upsertOccurrence` gravam-nos.
  `upsertOccurrence` continua sem criar linha quando todos os overrides são `null`.

## Regras (lógica pura em `lib/utils/time_range.dart`)

Sem dependência de banco ou Flutter. Minutos desde 00:00 como representação interna.

- **Validação** (`validate(start, end, breakStart, breakEnd)` → mensagem de erro ou `null`):
  - `end` exige `start`; `end > start`.
  - Pausa exige `end`; exige os dois extremos; `start ≤ breakStart < breakEnd ≤ end`.
- **Estado no instante** (`statusAt(...)` → `none | now | paused`):
  - sem `end` → `none` (D6);
  - `start ≤ t < end` → `paused` se `breakStart ≤ t < breakEnd`, senão `now`.
  - Limites: 15:00 com fim 15:00 → `none`; 12:00 com pausa 12:00–13:00 → `paused`.
- **Sobreposição** (`conflicts(a, b)`):
  - Tarefa sem fim = ponto `[start, start]`; com fim = `[start, end)` menos a pausa.
  - Dois intervalos conflitam se as partes ativas se interceptam; um ponto conflita se cai dentro
    da parte ativa do outro (D7: ponto/intervalo inteiramente dentro da pausa não conflita).
  - Tarefas sem `start` nunca conflitam.

## Validação na edição de ocorrência

O formulário mostra os valores **efetivos** do dia. A validação roda sobre o resultado efetivo
(override + regra). Ex.: regra 08–15 pausa 12–13, ocorrência muda fim para 11:00 → erro pedindo para
ajustar/remover a pausa nesse dia. A gravação continua salvando só o que difere da regra
(`''` = removido nesta data).

## Sobreposição ao salvar

`TaskService.findConflicts(...)` retorna as tarefas conflitantes:

- Avulsa: data `due_date`.
- Ocorrência: a data da ocorrência.
- Rotina (criar/editar regra): cada dia da semana da regra na semana que contém a data de início
  de vigência (criação: hoje).
- Exclui a própria tarefa. Usa as tarefas efetivas do dia (`getTasksForDate`), já com overrides.

Com conflitos, diálogo lista "Título · horário · data" e oferece **Salvar mesmo assim** / **Voltar**.

## Backup

- O export inclui as colunas novas automaticamente (exporta as colunas existentes da tabela).
- Import passa a aceitar `dbVersion` de **5 até `schemaVersion`**. Colunas ausentes em backups
  antigos ficam `NULL`. `dbVersion` maior que o do app continua recusado.
- Garante que `app_task_backup_rotina.json` (v5) continua importável.

## Telas

**Formulário (criar, editar, editar rotina, editar ocorrência):** bloco "Horário" progressivo —
Início; "Fim (opcional)" visível após início; "+ Adicionar pausa" visível após fim, abrindo
"Pausa de / até" com X para remover. Limpar início limpa fim e pausa; limpar fim limpa pausa.

**Card:** chip `08:00–15:00 · pausa 12:00–13:00` (ou só `05:50`). No dia de hoje, a tarefa em
andamento recebe borda destacada e etiqueta **Agora** / **Pausa**. A home recalcula a cada minuto
(`Timer.periodic`) apenas enquanto o dia selecionado é hoje; o timer é cancelado no `dispose`.

Ordenação do dia continua por horário de início.

## Testes

Novos, junto aos 50 existentes (`flutter test` + `flutter analyze` limpos):

- `time_range_test.dart`: validação (casos válidos e cada erro), `statusAt` nos limites,
  `conflicts` com/sem fim e com pausa (incluindo ponto dentro da pausa).
- Migração v5 → v6 preserva dados e cria colunas.
- Regra versionada: mudar intervalo a partir de uma data não altera semanas anteriores.
- Ocorrência: override e remoção (`''`) de fim/pausa só naquela data; validação efetiva.
- `findConflicts`: avulsa, ocorrência e rotina (por dia da semana), excluindo a própria tarefa.
- Backup: importar fixture v5 em banco v6; roundtrip v6 preserva intervalos; v7 recusado.

Telas: sem testes de widget no projeto; validadas por `analyze`, build do CI e uso no aparelho.
