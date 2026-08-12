# App Task 📋

Gerenciador de rotina semanal e tarefas avulsas — **NexCode Soluções em Tecnologia**.

> "Organize. Execute. Conclua."

---

## Stack

| Item | Tecnologia |
|------|-----------|
| Plataforma | Android |
| Linguagem | Dart |
| Framework | Flutter |
| Banco de Dados | SQFlite (SQLite) |
| IDE | VS Code |
| Versionamento | Git + GitHub |

---

## Estrutura do Projeto

```
lib/
 ├── main.dart
 ├── database/
 │     └── database_helper.dart      # Singleton SQLite, migração, seed, CRUD
 ├── models/
 │     ├── task.dart                 # Task (+ recorrência / arquivamento)
 │     ├── task_completion.dart      # Conclusão por data (recorrentes)
 │     └── subtask.dart
 ├── screens/
 │     ├── splash_screen.dart
 │     ├── home_screen.dart          # Abas por dia, busca, stats
 │     ├── task_form_screen.dart     # Recorrente ou avulsa
 │     └── archived_screen.dart      # Histórico somente leitura
 ├── services/
 │     └── task_service.dart
 ├── widgets/
 │     ├── task_tile.dart
 │     ├── empty_state.dart
 │     └── subtask_widget.dart
 └── utils/
       ├── app_theme.dart
       ├── validators.dart
       └── weekday_utils.dart
```

---

## Banco de Dados (apptask.db, versão 2)

### Tabela `tasks`
```sql
CREATE TABLE tasks(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    description TEXT,
    due_date TEXT,
    completed INTEGER DEFAULT 0,
    created_at TEXT NOT NULL,
    is_recurring INTEGER DEFAULT 0,
    recurring_days TEXT,          -- ex: "1,3,5" (1=Seg ... 7=Dom)
    time TEXT,                    -- ex: "08:00"
    archived INTEGER DEFAULT 0
);
```

### Tabela `subtasks`
```sql
CREATE TABLE subtasks(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    completed INTEGER DEFAULT 0,
    FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE
);
```

### Tabela `task_completions`
```sql
CREATE TABLE task_completions(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,
    completion_date TEXT NOT NULL,  -- YYYY-MM-DD
    completed INTEGER DEFAULT 1,
    FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE,
    UNIQUE(task_id, completion_date)
);
```

Recorrentes usam `task_completions` por data (reset diário natural). Avulsas usam `tasks.completed` e arquivam ao concluir.

Horário (`time`) é opcional para **recorrentes e avulsas**, e ordena a lista do dia.

### Atualizar o app sem perder dados

- O SQLite fica em `apptask.db` no armazenamento interno do app.
- Instalar um APK **mais novo** (mesmo `applicationId`, `versionCode` maior) preserva o banco; a migração `onUpgrade` só adiciona colunas/tabelas.
- O seed da rotina roda **somente** na primeira instalação (`onCreate`).
- **Desinstalar** o app ou “Limpar dados” apaga as tarefas — isso é comportamento do Android.

---

## Como Rodar

### Pré-requisitos
- Flutter SDK >= 3.0.0
- Android SDK / dispositivo Android 8.0+
- VS Code com extensão Flutter

### Passos

```bash
git clone https://github.com/GitHubPng/app_task.git
cd app_task
flutter pub get
flutter run
```

---

## Funcionalidades

| RF | Funcionalidade | Status |
|----|---------------|--------|
| RF01 | Cadastrar tarefa (recorrente ou avulsa, subtarefas) | ✅ |
| RF02 | Listar por dia da semana (horário + avulsas do dia) | ✅ |
| RF03 | Pesquisar tarefa em tempo real pelo título | ✅ |
| RF04 | Editar tarefa | ✅ |
| RF05 | Excluir tarefa (permanente, com confirmação) | ✅ |
| RF06 | Marcar como concluída (checkbox; recorrente por data) | ✅ |
| RF07 | Gerenciar subtarefas (add, concluir, excluir) | ✅ |
| RF08 | Estado vazio com mensagem orientativa | ✅ |
| RF09 | Splash Screen com logo e animação (2 segundos) | ✅ |
| RF10 | Tela Arquivadas (histórico avulsas concluídas) | ✅ |
| RF11 | Seed da rotina semanal no primeiro `onCreate` | ✅ |

---

## Regras de Negócio

| RN | Regra | Implementação |
|----|-------|--------------|
| RN01 | Título obrigatório | `Validators.validateTitle()` |
| RN02 | Data não retroativa (avulsas) | `Validators.isDateInPast()` + DatePicker |
| RN03 | Conclusão apenas por checkbox | Sem automação por data |
| RN04 | Exclusão permanente | Dialog de confirmação |
| RN05 | Subtarefa vinculada à tarefa pai | `ON DELETE CASCADE` |
| RN06 | Edição irrestrita | Sempre habilitada |
| RN07 | Busca apenas no título | `WHERE title LIKE '%query%'` |
| RN08 | Ordenação do dia por horário | `time` ASC |
| RN-NOVA-01 | Recorrente: 1+ dias da semana | Chips no formulário |
| RN-NOVA-02 | Conclusão recorrente por data | `task_completions` |
| RN-NOVA-03 | Recorrente não arquiva sozinha | Só some como “feita hoje” |
| RN-NOVA-04 | Avulsa arquiva ao concluir | `archived = 1` |
| RN-NOVA-05 | Arquivadas só consulta | Sem restaurar/editar/excluir |
| RN-NOVA-06 | Excluir recorrente limpa histórico | CASCADE em completions |

---

## Dependências (pubspec.yaml)

```yaml
dependencies:
  sqflite: ^2.3.3
  path: ^1.9.0
  intl: ^0.19.0
```

---

## Critérios de Teste

| Caso | Esperado |
|------|---------|
| Abrir app na 1ª vez | Rotina semanal seed aparece no dia certo |
| Selecionar dia | Lista só recorrentes daquele dia + avulsas da data |
| Concluir recorrente | Feita hoje; no dia seguinte volta desmarcada |
| Concluir avulsa | Some da home e vai para Arquivadas |
| Criar sem título | Erro "Título obrigatório" |
| Recorrente sem dias | Erro pedindo ao menos um dia |
| Buscar | Filtra em todos os dias (não só o selecionado) |
| Excluir | Remove tarefa, subtarefas e completions |

---

## Equipe — NexCode

| Nome | Email |
|------|-------|
| Marcos Rafael de Souza Mello | marcos406016@gmail.com |
| Gabriel Porto de Oliveira | gabrielporto1215@gmail.com |
| Caio Martins de Oliveira | martinsscaio18@gmail.com |

**QI - Faculdade e Escola Técnica | Desenvolvimento de Aplicativos II | 2026**
