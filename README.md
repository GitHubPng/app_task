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
 │     └── database_helper.dart      # Singleton SQLite, migração, CRUD
 ├── models/
 │     ├── task.dart                 # Task (+ recorrência / arquivamento)
 │     ├── task_completion.dart      # Conclusão por data (recorrentes)
 │     └── subtask.dart
 ├── screens/
 │     ├── splash_screen.dart
 │     ├── home_screen.dart          # Abas por dia, busca, stats
 │     └── task_form_screen.dart     # Recorrente ou avulsa
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

## Banco de Dados (apptask.db, versão 5)

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
    time TEXT                     -- ex: "08:00"
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

Outras tabelas (ver `_onCreate` em `database_helper.dart`):
- `task_recurrence_rules` — versões da regra da rotina (`effective_from`).
- `task_occurrences` — override ou cancelamento pontual de uma data.
- `subtask_completions` — conclusão de etapas de rotina por data.

Recorrentes usam `task_completions` por data (reset diário natural). Avulsas usam `tasks.completed` e ficam riscadas na própria data.

Horário (`time`) é opcional para **recorrentes e avulsas**, e ordena a lista do dia.

### Atualizar o app sem perder dados

- O SQLite fica em `apptask.db` no armazenamento interno do app.
- Instalar um APK **mais novo** (mesmo `applicationId`, `versionCode` maior) preserva o banco; a migração `onUpgrade` só adiciona colunas/tabelas.
- O app inicia **sem tarefas pré-cadastradas**; tudo é criado pelo usuário.
- **Desinstalar** o app ou “Limpar dados” apaga as tarefas — isso é comportamento do Android.
- O APK só atualiza por cima se for assinado com a **mesma chave**. Veja abaixo.

### Assinatura de release

O build de release usa `android/key.properties` (fora do Git). Sem ele, cai na chave de debug,
que é diferente em cada máquina — e o Android recusa instalar por cima.

**Gerar a chave (uma vez só — guarde o `.jks` e as senhas; perdeu = não atualiza mais):**

```bash
keytool -genkeypair -v -keystore upload-keystore.jks -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000
```

**Secrets no GitHub** (Settings → Secrets and variables → Actions):

| Secret | Valor |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | senha da keystore |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | senha da chave |

Sem os secrets, o workflow falha de propósito em vez de gerar um APK que não atualiza.

**Build local assinado:** copie o `.jks` para `android/app/` e crie `android/key.properties`:

```properties
storeFile=app/upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

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

---

## Regras de Negócio

| RN | Regra | Implementação |
|----|-------|--------------|
| RN01 | Título obrigatório | `Validators.validateTitle()` |
| RN02 | Avulsa exige data, não retroativa | `Validators.isDateInPast()` + DatePicker |
| RN03 | Conclusão apenas por checkbox | Sem automação por data |
| RN04 | Exclusão permanente | Dialog de confirmação |
| RN05 | Subtarefa vinculada à tarefa pai | `ON DELETE CASCADE` |
| RN06 | Edição irrestrita | Sempre habilitada |
| RN07 | Busca apenas no título | `WHERE title LIKE '%query%'` |
| RN08 | Ordenação do dia por horário | `time` ASC |
| RN-NOVA-01 | Recorrente: 1+ dias da semana | Chips no formulário |
| RN-NOVA-02 | Conclusão recorrente por data | `task_completions` |
| RN-NOVA-03 | Recorrente não arquiva sozinha | Só some como “feita hoje” |
| RN-NOVA-04 | Avulsa concluída fica riscada no dia | `tasks.completed` |
| RN-NOVA-05 | Não se conclui em data futura | Checkbox desabilitado |
| RN-NOVA-06 | Excluir recorrente: só a ocorrência ou a rotina inteira | Rotina inteira limpa histórico (CASCADE) |
| RN-NOVA-07 | Busca é só consulta | Sem concluir/excluir nos resultados |
| RN-NOVA-08 | Editar rotina preserva etapas mantidas | `syncSubtasks` mantém ids e histórico |

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
| Abrir app na 1ª vez | Lista vazia com mensagem orientativa |
| Selecionar dia | Lista só recorrentes daquele dia + avulsas da data |
| Concluir recorrente | Feita hoje; no dia seguinte volta desmarcada |
| Concluir avulsa | Fica riscada na data dela |
| Criar sem título | Erro "Título obrigatório" |
| Recorrente sem dias | Erro pedindo ao menos um dia |
| Buscar | Filtra em todos os dias (não só o selecionado) |
| Excluir avulsa / rotina inteira | Remove tarefa, subtarefas e completions |
| Excluir só a ocorrência | Some apenas daquela data |

---

## Equipe — NexCode

| Nome | Email |
|------|-------|
| Marcos Rafael de Souza Mello | marcos406016@gmail.com |
| Gabriel Porto de Oliveira | gabrielporto1215@gmail.com |
| Caio Martins de Oliveira | martinsscaio18@gmail.com |

**QI - Faculdade e Escola Técnica | Desenvolvimento de Aplicativos II | 2026**
