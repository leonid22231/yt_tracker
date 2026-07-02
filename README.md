# YouTrack Timer

Приложение для **автоматического планирования и заполнения рабочего времени** в [YouTrack](https://www.jetbrains.com/youtrack/) с **AI-оценкой** через [Cursor Cloud Agents API](https://cursor.com/docs/cloud-agent/api/endpoints), а также **аналитики GitLab-активности** и **сверки** с уже затреканным временем в YouTrack.

| Режим | Платформы | Назначение |
|-------|-----------|------------|
| **Flutter GUI** | Windows, Web (Chrome) | Построение плана, редактирование, проверка, запись, GitLab-аналитика |
| **CLI** | любая ОС с Dart/Flutter | Пакетная обработка периода из терминала |
| **Утилита очистки** | CLI | Удаление служебных комментариев из старых work items |

---

## Содержание

- [Возможности](#возможности)
- [Требования](#требования)
- [Версии SDK](#версии-sdk)
- [Установка](#установка)
- [Настройка окружения](#настройка-окружения)
- [FVM и IDE](#fvm-и-ide)
- [Запуск GUI](#запуск-gui)
- [Рабочий процесс: план времени](#рабочий-процесс-план-времени)
- [Митап](#митап)
- [Исключённые даты](#исключённые-даты)
- [GitLab + YouTrack Analysis](#gitlab--youtrack-analysis)
- [Как работает AI-оценка](#как-работает-ai-оценка)
- [Пересчёт плана](#пересчёт-плана)
- [Проверка и запись в YouTrack](#проверка-и-запись-в-youtrack)
- [Защита от случайной записи](#защита-от-случайной-записи)
- [CLI](#cli)
- [Очистка служебных комментариев](#очистка-служебных-комментариев)
- [Логирование](#логирование)
- [Безопасность](#безопасность)
- [Структура проекта](#структура-проекта)
- [Тесты](#тесты)
- [Устранение неполадок](#устранение-неполадок)
- [Коды выхода CLI](#коды-выхода-cli)

---

## Возможности

### Планирование времени (YouTrack)

- Загрузка задач за период (`assignee: me`) и построение плана на каждый рабочий день.
- **Cursor Agent** анализирует историю задач (activities, комментарии, статусы, оценки) и предлагает минуты по дням с обоснованием.
- **Fallback** без AI — равномерное распределение до N часов в день.
- Учёт **уже списанного** времени в YouTrack: план дополняет день до целевого лимита, а не дублирует записи.
- Шкала **«По дням»** показывает серым уже существующее время и синим — новый план; раскрытие дня — список задач.
- Вкладка **«Таймлайн»** — визуализация дня по часам.
- **Пересчёт** при смене часов/день, лимита на задачу или текстовой подсказки для AI (~1 с debounce).
- **Превью** — календарная сетка как в YouTrack + проверка дубликатов (только GET).
- **Ежедневные задачи** (тег `daily` или слово `daily` в названии) — учитываются каждый рабочий день.
- **Исключённые даты** — рабочие дни, которые не попадают в план.
- **Митап** — фиксированные минуты на отдельную задачу каждый рабочий день (с собственным списком «без митапа»).
- **Day plan capper** — гарантия `existing + planned ≤ hoursPerDay` на каждый день.

### GitLab + YouTrack Analysis

- Подключение к **GitLab.com** или **self-hosted** инстансу по Personal Access Token.
- **Демо-режим** — синтетические данные без API.
- Сбор **коммитов** и **веток** текущего пользователя за период.
- Извлечение **task ID** (`ABC-123`) из сообщений коммитов, названий веток и заголовков MR.
- Дневная аналитика: коммиты, задачи, изменения (+/−), оценка времени, индекс продуктивности.
- Графики (`fl_chart`): активность по дням, продуктивность, распределение по задачам.
- **Сверка с YouTrack** — сравнение затреканного времени и GitLab-активности по дням и по задачам (третья вкладка).
- Строгая фильтрация **автора коммитов** (email, username, noreply self-hosted).
- Учёт коммитов из **merge requests** пользователя и **push events**.

### Интерфейс и локализация

- Тёмная тема, боковая панель настроек, панель логов внизу.
- **Русская локаль** календаря и дат (`flutter_localizations`, `locale: ru`).
- Статус-пилюли: YouTrack, Cursor AI, GitLab, Dry-run.

---

## Требования

| Компонент | Версия / описание |
|-----------|-------------------|
| [FVM](https://fvm.app/) | Управление Flutter SDK |
| Flutter | **3.41.2** (закреплено в `.fvmrc`, `.fvm/fvm_config.json`, `pubspec.yaml`) |
| Dart | **3.11.x** (идёт с Flutter 3.41.2) |
| YouTrack | Permanent token (`perm:…`), scopes на чтение/запись work items |
| Cursor | API-ключ ([Dashboard → Integrations](https://cursor.com/dashboard/integrations)) — для AI |
| GitLab (опционально) | Personal Access Token с `read_api`, `read_repository` |

---

## Версии SDK

Проект жёстко привязан к **Flutter 3.41.2**:

```yaml
# pubspec.yaml
environment:
  sdk: '>=3.11.0 <3.12.0'
  flutter: 3.41.2
```

Файлы конфигурации:

- `.fvmrc` — `{ "flutter": "3.41.2" }`
- `.fvm/fvm_config.json` — `{ "flutterSdkVersion": "3.41.2" }`
- `.vscode/settings.json` — `"dart.flutterSdkPath": ".fvm/versions/3.41.2"`

> **Важно:** в `environment.sdk` указывается версия **Dart**, не Flutter. Flutter 3.41.2 = Dart 3.11.0.

---

## Установка

```bash
cd youtrack_timer
fvm install
fvm flutter pub get
copy .env.example .env   # Windows
# cp .env.example .env   # Linux/macOS
```

Заполните `.env` (файл в `.gitignore`, не коммитьте).

---

## Настройка окружения

### Файл `.env`

```env
# YouTrack — URL корня инстанса, БЕЗ /api
# Cloud:  https://your-company.youtrack.cloud
# On-prem: https://server.company.com/youtrack
YOUTRACK_URL=https://your-company.youtrack.cloud

# Permanent token (префикс perm: добавится автоматически)
YOUTRACK_TOKEN=your-permanent-token-here

# Cursor Agent (Cloud API) — для AI-оценки времени
CURSOR_API_KEY=cursor_your_api_key_here
```

При первом запуске GUI значения из `.env` **один раз** копируются в локальные настройки (SharedPreferences).

### Настройки в GUI

Сохраняются локально (SharedPreferences):

| Параметр | Описание |
|----------|----------|
| URL YouTrack | Нормализуется (без trailing slash, без `/api`) |
| Токен YouTrack | Префикс `perm:` добавляется автоматически |
| Cursor API key | Для AI-оценки |
| Use AI | Включить/выключить Cursor Agent |
| Dry-run | Блокирует запись в YouTrack |
| GitLab URL | По умолчанию `https://gitlab.com` |
| GitLab Token | Personal Access Token |
| GitLab Demo | Демо-данные без API |

GitLab-токен настраивается в **Настройки → GitLab** или на экране аналитики.

---

## FVM и IDE

### Команды через FVM

```bash
fvm flutter pub get
fvm flutter run -d windows
fvm flutter run -d chrome
fvm flutter test
fvm dart run bin/youtrack_timer.dart --help
```

### VS Code / Cursor

1. Установите FVM и выполните `fvm install` в корне проекта.
2. В `.vscode/settings.json` уже указан путь к SDK: `.fvm/versions/3.41.2`.
3. Если IDE ругается на типы в `gestures/events.dart` (`Offset isn't a type` и т.п.) — выбран **не тот** Flutter SDK (часто глобальный `fvm/default` или системный Dart 3.6).

**Исправление:**

1. Command Palette → **Dart: Change SDK** → `youtrack_timer/.fvm/versions/3.41.2` (или `.fvm/flutter_sdk`).
2. **Developer: Reload Window**.
3. Запускайте конфигурацию **Flutter: Windows (debug)** из `.vscode/launch.json`, не «Run Dart file».

> Терминальный `PATH` не влияет на SDK, который использует отладчик IDE — только `dart.flutterSdkPath`.

**Не запускайте UI через системный `dart run`** — на Windows в PATH часто лежит отдельный Dart SDK, несовместимый с Flutter.

---

## Запуск GUI

```bash
fvm flutter run -d windows
# или:
fvm flutter run -d chrome
```

Точка входа: `lib/main.dart` → `YouTrackTimerApp` → `HomeScreen`.

---

## Рабочий процесс: план времени

### 1. Настройки

Откройте **шестерёнку** в боковой панели:

- URL и токен YouTrack → **Проверить подключение**
- Cursor API key, переключатель AI
- **Dry-run** (рекомендуется оставить включённым до проверки плана)

### 2. Период

Выберите **С** и **По** в боковой панели. Календарь на русском языке.

### 3. Исключённые даты и митап

См. разделы ниже — настраиваются до построения плана.

### 4. Часы в день

Слайдер **часов в день** (по умолчанию 8). Целевой итог на день = уже в YouTrack + новый план.

### 5. Построить план

Кнопка **«Построить план»** / **«Обновить план»**:

1. Загрузка задач из YouTrack
2. Загрузка activities и work items по каждой задаче
3. Запрос к Cursor Agent (если AI включён) или fallback-распределение
4. Применение митапа, gap filler, day capper
5. Построение таймлайнов по дням

### 6. Редактирование

- Вкладка **«По задачам»** — список записей плана, исключение задач, ручной лимит минут.
- Вкладка **«По дням»** / **«Таймлайн»** — визуализация.
- Поле **подсказки для пересчёта** — текст уходит в AI при следующем пересчёте.

### 7. Проверка и запись

- **Проверить** — превью-календарь + симуляция без POST.
- **Записать в YouTrack** — только при выключенном Dry-run + диалог подтверждения.

---

## Митап

Блок **«Митап»** в боковой панели:

| Поле | Описание |
|------|----------|
| Переключатель | Включить/выключить митап |
| ID задачи | Например `TEAM-42` |
| Минуты в день | Целевой **итог** на задачу в день (не «добавить сверху») |
| **Без митапа** | Дни, когда митап не начисляется (отдельно от глобальных исключённых дат) |

Логика (`MeetupAllocator`):

- На каждый рабочий день (кроме исключённых дат плана и «без митапа») выравнивает время на задаче митапа до `minutesPerDay`.
- Учитывает уже списанное в YouTrack — добавляет только **дополнительные** минуты.
- Если задача не найдена в YouTrack за период — митап не применяется.

---

## Исключённые даты

Блок **«Исключить даты»**:

- Рабочие дни, **полностью исключённые из расчёта плана** (ни AI, ни fallback не создают записи на эти даты).
- Пример: отпуск на 14 и 16 число внутри месяца.
- **Не связаны** с «Без митапа» у митапа — это два независимых списка.

Записи на исключённые дни отфильтровываются и после ответа AI (`PlanCalculationOptions.filterExcludedDays`).

---

## GitLab + YouTrack Analysis

Кнопка **«GitLab аналитика»** на главном экране.

### Подключение

**Настройки → GitLab** (или иконка на экране аналитики):

| Поле | Описание |
|------|----------|
| URL | `https://gitlab.com` или `https://gitlab.company.com` |
| Token | Personal Access Token (`read_api`, `read_repository`) |
| Демо-режим | Синтетические данные без сети |

### Экран аналитики

**Вкладки:**

1. **Обзор** — сводка за период, карточки по дням, ключевые метрики.
2. **Графики** — коммиты/изменения по дням, продуктивность, задачи.
3. **YouTrack** — сверка затреканного времени с GitLab (кнопка «Загрузить YouTrack»).

**Панель инструментов:**

- Период (независим от периода плана на главном экране)
- **Обновить** — загрузка данных из GitLab API
- **Пересчитать** — локальный пересчёт метрик
- **Загрузить YouTrack** — work items за период + сравнение

### Как собираются коммиты

1. MR текущего пользователя (`author_id`) — коммиты MR доверяются как авторские.
2. SHA из **push events** пользователя.
3. Сканирование проектов-участника с фильтром `GitLabCommitAuthor.matches` (email, name, noreply).

### Task ID

Регулярное выражение: `\b([A-Z][A-Z0-9]+-\d+)\b` — из commit message, branch name, MR title.

### Оценка времени по GitLab

Эвристика (`GitLabTimeEstimator`):

- ~25 мин/коммит, ~15 мин/задача, ~10 мин/100 изменений, ~5 мин/ветка
- Потолок ~600 мин/день
- Индекс продуктивности 0–100

### Self-hosted GitLab

Поддерживаются noreply-email вида `id+user@users.noreply.<host>` (например `users.noreply.gitlab.evosoft.xyz`).

---

## Как работает AI-оценка

1. **План** — задачи с `assignee: me` (парсинг поля assignee в API).
2. Если таких нет — fallback на задачи, где есть **ваше** списанное время (work author).
3. **Шкала «По дням»** дополнительно показывает время на задачах без assignee (например коллеги), без попадания в план справа.
4. Для каждой задачи плана: **activities**, **existingWorkItems** (только ваши), **taskEstimate**.
5. AI предлагает **дополнительные** минуты с учётом оценки и уже списанного; не выходит за `taskEstimateRemainingMinutes`.
6. Контекст отправляется в **Cursor Agent** (JSON, без репозитория).
7. Агент возвращает JSON: минуты по дням + reasoning.
8. Сумма дополнительных минут нормализуется: цель = `hoursPerDay − existing`.
9. Daily-задачи дополняют пробелы (`DayGapFiller`), если день недозаполнен.
10. `DayPlanCapper` обрезает план, если `existing + planned > hoursPerDay`.

---

## Пересчёт плана

Триггеры:

- Смена **часов в день**
- Ручной **лимит минут** на задачу
- Текстовая **подсказка** для AI
- Изменение настроек **митапа** (с debounce)

Процесс:

1. Повторная загрузка activities и work items из YouTrack
2. Cursor Agent в режиме `recalculation` с `userBudgetMinutesForPeriod`
3. При недоступности AI — локальный `PlanRecalculator` (fallback)
4. Повторное применение митапа и capper

---

## Проверка и запись в YouTrack

### Проверить (dry preview)

- Календарная сетка в стиле YouTrack
- `SubmitService` в режиме симуляции
- Проверка дубликатов — **только GET**
- Ссылки на задачи в YouTrack

### Записать

- `createWorkItem` — POST только с `allowWrite: true`
- Без комментария в записи (только время и дата)
- Диалог с чекбоксом «Я понимаю…»

---

## Защита от случайной записи

| Механизм | Поведение |
|----------|-----------|
| **Проверить** | Никогда не вызывает POST |
| **Dry-run** в настройках | Кнопка записи заблокирована |
| **Диалог** | Чекбокс подтверждения |
| **SubmitGuard** | POST запрещён без явного флага |
| **Логи** | Токены и ключи маскируются |

---

## CLI

```bash
fvm dart run youtrack_timer --start-date 2024-01-01 --end-date 2024-01-31
fvm dart run youtrack_timer -s 2024-01-01 -e 2024-01-31 --dry-run
```

Точка входа: `bin/youtrack_timer.dart`. Читает `.env` через `dotenv`.

Конфигурации запуска в `.vscode/launch.json`: **CLI: dry-run**, **CLI: с датами**.

---

## Очистка служебных комментариев

Если раньше приложение писало в work items текст вроде `AI-оценка youtrack_timer`:

```bash
# Список (без изменений)
fvm dart run bin/cleanup_work_item_comments.dart

# Удалить
fvm dart run bin/cleanup_work_item_comments.dart --write

# За период
fvm dart run bin/cleanup_work_item_comments.dart -s 2026-05-01 -e 2026-05-31 --write
```

---

## Логирование

| Аспект | Детали |
|--------|--------|
| Уровни | `DEBUG`, `INFO`, `OK`, `WARN`, `ERROR` |
| Категории | `app`, `youtrack`, `cursor`, `plan`, `submit` |
| Санитизация | Токены и ключи маскируются (`LogSanitizer`) |
| Консоль | При `flutter run` и CLI |
| Файл (Windows) | `%AppData%/youtrack_timer/logs/youtrack_timer_YYYY-MM-DD.log` |
| UI | Панель внизу — фильтр, копирование, сворачивание |

---

## Безопасность

- Токены **не попадают в логи** в открытом виде
- `.env` в `.gitignore`
- API-ключи хранятся только локально (SharedPreferences)
- GitLab token — только для чтения (scopes `read_api`, `read_repository`)

---

## Структура проекта

```
youtrack_timer/
├── .fvm/                          # FVM: Flutter 3.41.2
├── .vscode/                       # launch.json, settings.json
├── bin/
│   ├── youtrack_timer.dart        # CLI
│   └── cleanup_work_item_comments.dart
├── lib/
│   ├── main.dart                  # Flutter entry
│   ├── agent/
│   │   └── cursor_agent_client.dart
│   ├── config/
│   │   ├── app_config.dart
│   │   └── env_loader.dart
│   ├── gitlab/
│   │   ├── gitlab_client.dart     # GitLab API v4
│   │   ├── gitlab_commit_author.dart
│   │   ├── gitlab_credentials.dart
│   │   ├── gitlab_mock_data.dart
│   │   └── youtrack_tracked_mock_data.dart
│   ├── logging/                   # AppLog, LogSanitizer, sink
│   ├── models/
│   │   ├── meetup_settings.dart
│   │   ├── plan_calculation_options.dart
│   │   ├── gitlab/                # CommitRecord, DailyActivitySummary, …
│   │   └── …                      # Issue, WorkItem, DayTimeline, …
│   ├── providers/
│   │   ├── app_state.dart         # HomeState, settings, plan
│   │   ├── gitlab_provider.dart
│   │   └── log_provider.dart
│   ├── services/
│   │   ├── ai_time_estimator.dart
│   │   ├── plan_builder_service.dart
│   │   ├── plan_recalculator.dart
│   │   ├── meetup_allocator.dart
│   │   ├── day_plan_capper.dart
│   │   ├── day_gap_filler.dart
│   │   ├── day_timeline_builder.dart
│   │   ├── time_distributor.dart
│   │   ├── submit_service.dart
│   │   ├── settings_store.dart
│   │   └── gitlab/
│   │       ├── gitlab_activity_service.dart
│   │       ├── gitlab_analytics_service.dart
│   │       ├── gitlab_time_estimator.dart
│   │       ├── task_id_extractor.dart
│   │       ├── youtrack_tracked_time_service.dart
│   │       └── youtrack_gitlab_analyzer.dart
│   ├── ui/
│   │   ├── app.dart
│   │   ├── screens/
│   │   │   ├── home_screen.dart
│   │   │   ├── settings_screen.dart
│   │   │   ├── plan_preview_screen.dart
│   │   │   ├── gitlab_analysis_screen.dart
│   │   │   └── gitlab_settings_screen.dart
│   │   ├── widgets/
│   │   │   ├── excluded_dates_control.dart
│   │   │   ├── meetup_settings_control.dart
│   │   │   ├── gitlab/            # charts, comparison view
│   │   │   └── …
│   │   ├── utils/
│   │   │   ├── app_date_picker.dart
│   │   │   └── time_format.dart
│   │   └── theme/
│   └── youtrack/                  # YouTrack API client, parsers
├── test/                          # unit + widget tests
├── pubspec.yaml
├── .env.example
└── CHANGELOG.md
```

---

## Тесты

```bash
fvm flutter test
```

| Файл | Что проверяет |
|------|---------------|
| `youtrack_timer_test.dart` | CLI, базовый flow |
| `plan_recalculator_test.dart` | Локальный пересчёт |
| `time_distributor_test.dart` | Равномерное распределение |
| `day_timeline_builder_test.dart` | Таймлайны |
| `meetup_allocator_test.dart` | Митап, исключённые дни митапа |
| `gitlab_analytics_test.dart` | Метрики GitLab |
| `gitlab_commit_author_test.dart` | Фильтр автора, noreply |
| `youtrack_gitlab_analyzer_test.dart` | Сверка YT ↔ GitLab |
| `log_sanitizer_test.dart` | Маскировка секретов |
| `youtrack_credentials_test.dart` | Нормализация URL/токена |
| `issue_assignee_parser_test.dart` | Парсинг assignee |
| `issue_estimate_parser_test.dart` | Оценки задач |
| `work_item_*_test.dart` | Work items, авторы, даты |
| `widget_test.dart` | Smoke-тест приложения |

---

## Устранение неполадок

### Ошибки типов в `flutter/material.dart` / `gestures/events.dart`

IDE использует не тот Flutter SDK. См. [FVM и IDE](#fvm-и-ide).

### GitLab показывает чужие коммиты

Обновите до версии с `GitLabCommitAuthor` — коммиты фильтруются по email/username/noreply. MR пользователя учитываются отдельно.

### MR не попадает в аналитику

Проверьте: период включает дату MR, токен с `read_api` + `read_repository`, MR создан вами (`author_id`). Для self-hosted — email noreply домена инстанса.

### AI не отвечает / fallback

Проверьте Cursor API key, переключатель **Use AI**, логи категории `cursor`. План всё равно строится через `TimeDistributor`.

### Запись заблокирована

Включён **Dry-run** — выключите в настройках после проверки плана.

### Календарь на английском

Убедитесь, что в `lib/ui/app.dart` задано `locale: Locale('ru')` и подключён `flutter_localizations`.

---

## Коды выхода CLI

| Код | Значение |
|-----|----------|
| 0 | Успех |
| 1 | Ошибка аргументов |
| 2 | Ошибка API |

---

## Лицензия

Проект не публикуется на pub.dev (`publish_to: none`).

См. [CHANGELOG.md](CHANGELOG.md) для истории изменений.
