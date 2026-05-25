# YouTrack Timer

Приложение для автоматического заполнения рабочего времени в [YouTrack](https://www.jetbrains.com/youtrack/) с **AI-оценкой** через [Cursor Cloud Agents API](https://cursor.com/docs/cloud-agent/api/endpoints).

- **Flutter UI** (Windows / Web) — настройки, план, отправка
- **CLI** — прежний режим из терминала
- **Cursor Agent** анализирует историю задач (комментарии, статусы) и предлагает минуты на каждый день
- **Fallback** — равномерные 8 ч/день, если AI недоступен

## Требования

- [FVM](https://fvm.app/) — управление версией Flutter
- Dart 3.6+
- Permanent token YouTrack (`perm:…`)
- API-ключ Cursor ([Dashboard → Integrations](https://cursor.com/dashboard/integrations)) — для AI

## FVM

Проект привязан к **stable** через `.fvmrc`:

```bash
cd youtrack_timer
fvm install
fvm use stable
```

Все команды Flutter — через `fvm`:

```bash
fvm flutter pub get
fvm flutter run -d windows
fvm flutter test
```

VS Code/Cursor подхватывает SDK из `.fvm/flutter_sdk` (см. `.vscode/settings.json`).

**Не запускайте UI через системный `dart run`** — на Windows часто в PATH лежит отдельный Dart 3.6 (`C:\tools\dart-sdk`), он не совместим с Flutter stable (Dart 3.11). Симптом: сотни ошибок в `gestures/events.dart` (`Offset isn't a type`, `PointerDeviceKind isn't a type`).

Запуск только так:

```bash
fvm flutter run -d windows
```

Если IDE всё равно ругается: Command Palette → **Dart: Change SDK** → `youtrack_timer/.fvm/flutter_sdk`, затем **Developer: Reload Window**. Конфигурация запуска — **Flutter: Windows**, не «Run Dart file».

## Установка

```bash
cd youtrack_timer
fvm flutter pub get
copy .env.example .env
```

Заполните `.env` (не коммитьте):

```env
YOUTRACK_URL=https://your-company.youtrack.cloud
YOUTRACK_TOKEN=perm:your-token
CURSOR_API_KEY=cursor_your_api_key
```

В GUI настройки также сохраняются локально (SharedPreferences).

## Запуск GUI (Flutter)

```bash
fvm flutter run -d windows
# или web:
fvm flutter run -d chrome
```

### Рабочий процесс в UI

1. **Настройки** — URL YouTrack, токен, Cursor API key, включить AI и dry-run
2. Выберите **период** (с / по)
3. **Построить план** — загрузка задач → история → Cursor Agent → нормализация до N ч/день
4. Слева **«По дням»** — уже списанное в YouTrack (серое) + новый план (синее); раскройте день для списка задач
5. Изменение **часов в день** или **лимита на задачу** — повторный запрос к Cursor Agent (~1 с задержка)
6. **Проверить (без записи)** — симуляция + проверка дубликатов (только GET)
7. **Записать в YouTrack** — только при выключенном Dry-run + диалог с галочкой подтверждения

### Защита от случайной записи

- **Проверить** — никогда не вызывает POST в API
- **Dry-run** в настройках — блокирует кнопку записи
- **Диалог** — чекбокс «Я понимаю…» перед записью
- **createWorkItem** — POST запрещён без `allowWrite: true`

## Запуск CLI

```bash
fvm dart run youtrack_timer --start-date 2024-01-01 --end-date 2024-01-31
fvm dart run youtrack_timer -s 2024-01-01 -e 2024-01-31 --dry-run
```

## Очистка служебных комментариев в work items

Если раньше приложение писало в записи текст вроде `AI-оценка youtrack_timer`:

```bash
# Сначала список (без изменений в YouTrack)
fvm dart run bin/cleanup_work_item_comments.dart

# Удалить комментарии
fvm dart run bin/cleanup_work_item_comments.dart --write

# За период
fvm dart run bin/cleanup_work_item_comments.dart -s 2026-05-01 -e 2026-05-31 --write
```

Новые записи из приложения **без комментария** (только время и дата).

## Как работает AI-оценка

1. **План и AI** — только задачи с `assignee: me` (проверка поля assignee в API)
2. **Шкала «По дням»** — дополнительно ваше списанное время на задачах, где вы не assignee (например KIOSK-114), без попадания в план справа
3. Для каждой задачи плана — **activities**, **existingWorkItems** (только **ваши** записи) и **taskEstimate**
4. AI предлагает **дополнительные** минуты с учётом оценки и уже списанного; не выходит за `taskEstimateRemainingMinutes`
5. Контекст отправляется в **Cursor Agent** (без репозитория — только JSON)
6. Агент возвращает JSON с минутами по дням и обоснованием
7. Сумма **дополнительных** минут по дню нормализуется с учётом уже списанного: цель = часы/день − existing
8. Daily-задачи дополняют пробелы, если день недозаполнен

## Пересчёт

При смене часов/день или ручного лимита на задачу:

1. Заново загружаются activities и work items из YouTrack
2. Cursor Agent перераспределяет план (режим `recalculation`, учёт `userBudgetMinutesForPeriod`)
3. При недоступности AI — локальный `PlanRecalculator` (fallback)

## Ежедневные задачи (daily)

Тег `daily` или слово `daily` в названии — учитываются каждый рабочий день.

## Логирование

- Уровни: `DEBUG`, `INFO`, `OK`, `WARN`, `ERROR`
- Категории: `app`, `youtrack`, `cursor`, `plan`, `submit`
- Токены и ключи **маскируются** в сообщениях
- **Консоль** — при `flutter run` и CLI
- **Файл** (Windows): `%AppData%/youtrack_timer/logs/youtrack_timer_YYYY-MM-DD.log`
- В UI: панель внизу — фильтр по уровню, копирование, очистка

## Безопасность

- Токены **не логируются** (санитизация в [LogSanitizer](lib/logging/log_sanitizer.dart))
- `.env` в `.gitignore`
- API-ключ Cursor хранится локально в настройках приложения

## Структура

```
lib/
  main.dart                 # Flutter entry
  agent/cursor_agent_client.dart
  ui/                       # экраны и тема
  services/
    ai_time_estimator.dart
    plan_builder_service.dart
  youtrack/youtrack_client.dart
bin/youtrack_timer.dart     # CLI
.fvmrc                      # Flutter stable
```

## Тесты

```bash
fvm flutter test
fvm dart test
```

## Коды выхода (CLI)

| Код | Значение        |
|-----|-----------------|
| 0   | Успех           |
| 1   | Ошибка аргументов |
| 2   | Ошибка API      |
