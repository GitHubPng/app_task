# App Task 📋

Gerenciador de tarefas desenvolvido pela **NexCode Soluções em Tecnologia**.

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
 │     └── database_helper.dart      # Singleton SQLite, CRUD de baixo nível
 ├── models/
 │     ├── task.dart                 # Entidade Task com toMap/fromMap
 │     └── subtask.dart              # Entidade Subtask com toMap/fromMap
 ├── screens/
 │     ├── splash_screen.dart        # Splash 2s com animação
 │     ├── home_screen.dart          # Lista, busca, stats
 │     └── task_form_screen.dart     # Formulário criar/editar
 ├── services/
 │     └── task_service.dart         # Camada intermediária UI ↔ banco
 ├── widgets/
 │     ├── task_tile.dart            # Card de tarefa na lista
 │     ├── empty_state.dart          # Estado vazio
 │     └── subtask_widget.dart       # Item de subtarefa
 └── utils/
       ├── app_theme.dart            # Tema, cores, estilos globais
       └── validators.dart           # Validações de título, data, formatação
```

---

## Banco de Dados (apptask.db)

### Tabela `tasks`
```sql
CREATE TABLE tasks(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    description TEXT,
    due_date TEXT,
    completed INTEGER DEFAULT 0,
    created_at TEXT NOT NULL
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

---

## Como Rodar

### Pré-requisitos
- Flutter SDK >= 3.0.0
- Android SDK / dispositivo Android 8.0+
- VS Code com extensão Flutter

### Passos

```bash
# 1. Clonar o repositório
git clone https://github.com/SEU_USUARIO/app_task.git
cd app_task

# 2. Instalar dependências
flutter pub get

# 3. Conectar dispositivo Android ou iniciar emulador

# 4. Rodar o app
flutter run
```

---

## Funcionalidades

| RF | Funcionalidade | Status |
|----|---------------|--------|
| RF01 | Cadastrar tarefa (título, desc, data, subtarefas) | ✅ |
| RF02 | Listar tarefas (pendentes primeiro, mais recentes no topo) | ✅ |
| RF03 | Pesquisar tarefa em tempo real pelo título | ✅ |
| RF04 | Editar tarefa | ✅ |
| RF05 | Excluir tarefa (permanente, com confirmação) | ✅ |
| RF06 | Marcar como concluída (checkbox, texto riscado) | ✅ |
| RF07 | Gerenciar subtarefas (add, concluir, excluir) | ✅ |
| RF08 | Estado vazio com mensagem orientativa | ✅ |
| RF09 | Splash Screen com logo e animação (2 segundos) | ✅ |

---

## Regras de Negócio

| RN | Regra | Implementação |
|----|-------|--------------|
| RN01 | Título obrigatório | `Validators.validateTitle()` |
| RN02 | Data não retroativa | `Validators.isDateInPast()` + DatePicker bloqueado |
| RN03 | Conclusão apenas por checkbox | Sem automação por data |
| RN04 | Exclusão permanente | Dialog de confirmação, sem lixeira |
| RN05 | Subtarefa vinculada à tarefa pai | `ON DELETE CASCADE` no SQLite |
| RN06 | Edição irrestrita | Sempre habilitada independente do status |
| RN07 | Busca apenas no título | `WHERE title LIKE '%query%'` |
| RN08 | Ordenação: pendentes primeiro, mais recentes no topo | `ORDER BY completed ASC, created_at DESC` |

---

## Dependências (pubspec.yaml)

```yaml
dependencies:
  sqflite: ^2.3.3    # SQLite para Flutter
  path: ^1.9.0       # Localização do banco no dispositivo
  intl: ^0.20.2      # Formatação de datas
```

---

## Critérios de Teste

| Caso | Esperado |
|------|---------|
| Criar tarefa com título | Salva e aparece na lista |
| Criar sem título | Mensagem de erro "Título obrigatório" |
| Selecionar data passada | DatePicker bloqueia, validação barra |
| Editar tarefa | Dados atualizados na lista |
| Excluir tarefa | Removida permanentemente com subtarefas |
| Fechar e reabrir app | Dados persistem (SQLite) |
| Concluir tarefa | Checkbox marca, texto riscado, vai para o final |
| Pesquisar | Filtra em tempo real pelo título |
| Lista vazia | Estado vazio com orientação |
| Busca sem resultado | Estado vazio com "Nenhuma tarefa encontrada" |

---

## Equipe — NexCode

| Nome | Email |
|------|-------|
| Marcos Rafael de Souza Mello | marcos406016@gmail.com |
| Gabriel Porto de Oliveira | gabrielporto1215@gmail.com |
| Caio Martins de Oliveira | martinsscaio18@gmail.com |

**QI - Faculdade e Escola Técnica | Desenvolvimento de Aplicativos II | 2026**
