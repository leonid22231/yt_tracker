# Changelog

Все заметные изменения проекта документируются в этом файле.

Формат основан на [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/),
версионирование — [Semantic Versioning](https://semver.org/lang/ru/).

## [Unreleased]

### Добавлено

#### GitLab + YouTrack Analysis (новый модуль)

- Экран **GitLab аналитика** с главной страницы и раздел GitLab в настройках.
- HTTP-клиент **GitLab API v4** (`lib/gitlab/gitlab_client.dart`):
  - текущий пользователь, ping, список проектов-участника;
  - коммиты из MR пользователя (`author_id`), push event SHA, сканирование проектов;
  - активность веток по push events;
  - загрузка статистики коммитов (additions/deletions).
- Модели данных (`lib/models/gitlab/`):
  - `CommitRecord`, `BranchRecord`, `TaskReference`;
  - `DailyActivitySummary`, `ProductivityMetric`, `GitLabActivityData`;
  - `GitLabUserInfo` с `knownEmailsForHost()` для self-hosted noreply;
  - `TrackedWorkEntry`, `YouTrackGitLabComparison` для сверки с YouTrack.
- Сервисы (`lib/services/gitlab/`):
  - `GitLabActivityService` — загрузка и обогащение task ID;
  - `GitLabAnalyticsService` — дневные сводки и метрики;
  - `GitLabTimeEstimator` — эвристическая оценка минут и индекс продуктивности;
  - `TaskIdExtractor` — regex `\b([A-Z][A-Z0-9]+-\d+)\b`;
  - `YouTrackTrackedTimeService` — work items из YouTrack за период;
  - `YouTrackGitLabAnalyzer` — сравнение по дням и задачам, статусы alignment.
- UI:
  - `GitLabAnalysisScreen` — 3 вкладки: Обзор, Графики, YouTrack;
  - `GitLabSettingsScreen` — URL, token, демо-режим, проверка подключения;
  - виджеты `gitlab_activity_charts.dart` (fl_chart), `gitlab_daily_summary_card.dart`, `youtrack_gitlab_comparison_view.dart`.
- `GitLabProvider` (Riverpod) — состояние подключения, период, загрузка, сравнение.
- **Демо-режим** — `GitLabMockData`, `YouTrackTrackedMockData` без сети.
- Настройки в `SettingsStore`: `gitLabUrl`, `gitLabToken`, `gitLabDemoMode`.
- Зависимость `fl_chart: ^0.70.2`.
- Тесты: `gitlab_analytics_test.dart`, `gitlab_commit_author_test.dart`, `youtrack_gitlab_analyzer_test.dart`.

#### Фильтрация автора GitLab

- `GitLabCommitAuthor.matches` — сопоставление по email, name, username.
- Поддержка noreply на gitlab.com и self-hosted (`users.noreply.<host>`).
- Коммиты из MR текущего пользователя (`fromUserMergeRequest: true`) доверяются без повторной проверки email.
- Исправлена проблема отображения чужих коммитов при широком сканировании проектов.
- Исправлен пропуск MR с task ID в заголовке и коммитами без прямого push event.

#### Локализация и календарь

- `flutter_localizations` в зависимостях.
- `locale: ru` в `YouTrackTimerApp` (`lib/ui/app.dart`).
- Общий хелпер `showAppDatePicker` (`lib/ui/utils/app_date_picker.dart`).
- Русские даты в `PeriodSelector`, `ExcludedDatesControl`, `MeetupSettingsControl`.

#### Митап: исключённые дни

- Поле `MeetupSettings.excludedDates` — дни **без митапа**, независимо от глобальных исключённых дат плана.
- UI-чипы «Без митапа» в `MeetupSettingsControl` с добавлением/удалением дат.
- `MeetupAllocator` пропускает дни из `meetup.isDayExcluded()`.
- `PlanRecalculator` и `AiTimeEstimator` учитывают исключённые дни митапа в промпте/логике.
- Методы `addMeetupExcludedDate` / `removeMeetupExcludedDate` в `app_state.dart`.
- Расширены тесты `meetup_allocator_test.dart`.

#### Версии SDK

- `pubspec.yaml`: `sdk: '>=3.11.0 <3.12.0'`, `flutter: 3.41.2`.
- `.fvmrc` и `.fvm/fvm_config.json` — Flutter **3.41.2** (вместо `stable`).
- `.vscode/settings.json`: `dart.flutterSdkPath` → `.fvm/versions/3.41.2`.

### Изменено

- `home_screen.dart` — кнопка «GitLab аналитика», статус-пилюля GitLab.
- `settings_screen.dart` — секция перехода к настройкам GitLab.
- `log_sanitizer.dart` — маскировка GitLab token в логах.
- Удалён диапазон дат митапа (С/По) в пользу списка исключённых дней митапа.

---

## [1.0.1] — 2026-07-03

### Добавлено

#### Митап (ежедневная задача)

- Модель `MeetupSettings` — включение, ID задачи, минуты в день.
- `MeetupAllocator` — выравнивание времени на задаче митапа до целевого итога в день с учётом уже списанного в YouTrack.
- UI `MeetupSettingsControl` в боковой панели: переключатель, поле задачи, слайдер минут.
- Интеграция в `PlanBuilderService`, `PlanRecalculator`, `AiTimeEstimator`.

#### Исключённые даты плана

- `PlanCalculationOptions` — `excludedDates`, `workingDays()`, `filterExcludedDays()`.
- UI `ExcludedDatesControl` — чипы с датами, исключённые из расчёта плана.
- `DateUtils.activeWorkingDays()` — рабочие дни минус исключения.

#### Day plan capper

- `DayPlanCapper` — гарантия `existing (YouTrack) + planned ≤ minutesPerDay` на каждый день с пропорциональным урезанием записей.

#### Подсказка для пересчёта

- Поле `RecalcHintField` — текстовая подсказка уходит в Cursor Agent при пересчёте.

#### Пустые дни / gap filler

- Доработка `DayGapFiller` и `day_timeline_builder` для корректного заполнения недозаполненных дней.
- `plan_builder_service` — fallback на задачи по work author, если нет `assignee: me`.

### Изменено

- `app_state.dart` — хранение `excludedDates`, `meetupSettings`, `PlanCalculationOptions`.
- `time_distributor.dart`, `plan_recalculator.dart` — учёт исключённых дат и митапа.
- `cursor_agent_client.dart` — мелкие правки для recalculation.
- `widget_test.dart` — smoke-тест с новыми контролами.

### Тесты

- `meetup_allocator_test.dart` — базовые сценарии митапа и дополнительных минут.

---

## [1.0.0] — 2026-07-03

Первый релиз: Flutter-приложение для планирования и записи рабочего времени в YouTrack.

### Добавлено

#### Ядро приложения

- Flutter UI (Windows / Web) и CLI (`bin/youtrack_timer.dart`).
- Riverpod state management (`app_state.dart`, `settingsProvider`).
- Тёмная тема (`app_theme.dart`, `app_colors.dart`).
- Локальные настройки через `SharedPreferences` + синхронизация из `.env`.

#### YouTrack

- `YouTrackClient` — issues, activities, work items, create work item.
- Запрос задач `assignee: me` за период.
- Парсеры: assignee, estimate, work item author, query builder.
- Нормализация URL и токена (`YouTrackCredentials`).
- Ссылки на задачи (`youtrack_links.dart`).

#### AI-оценка (Cursor Agent)

- `CursorAgentClient` — Cloud Agents API.
- `AiTimeEstimator` — формирование контекста и парсинг JSON-ответа.
- Учёт activities, existing work items, task estimate, remaining budget.
- Режим `recalculation` при изменении параметров плана.

#### Построение плана

- `PlanBuilderService` — оркестрация загрузки и сборки плана.
- `TimeDistributor` — fallback равномерного распределения (8 ч/день по умолчанию).
- `PlanRecalculator` — локальный пересчёт без AI.
- `DayGapFiller` — daily-задачи для недозаполненных дней.
- `DayTimelineBuilder` — таймлайны по дням.
- `PlanPreviewBuilder` — данные для превью-календаря.

#### UI: главный экран

- Боковая панель: период, часы/день, статусы подключений.
- Вкладки «По задачам» и «Таймлайн».
- Кнопки: Построить план, Проверить, Записать в YouTrack.
- `PlanListView`, `DayTimelineView`, `DaySummaryBar`, `HoursPerDayControl`.
- AI insight banner с summary от агента.
- Панель логов (`LogPanel`) с фильтрацией.

#### UI: настройки и превью

- `SettingsScreen` — YouTrack URL/token, Cursor key, AI, dry-run, тест подключения.
- `PlanPreviewScreen` — календарная сетка (`YoutrackCalendarGrid`), симуляция submit.
- `ConfirmWriteDialog` — подтверждение записи с чекбоксом.

#### Запись в YouTrack

- `SubmitService` — пакетная запись work items.
- `SubmitGuard` — запрет POST без `allowWrite: true`.
- Dry-run на уровне настроек и CLI.

#### Логирование

- `AppLog`, уровни и категории.
- `LogSanitizer` — маскировка токенов и API-ключей.
- Файловый sink (Windows: `%AppData%/youtrack_timer/logs/`).
- `LogProvider` для UI.

#### CLI и утилиты

- `bin/youtrack_timer.dart` — аргументы `--start-date`, `--end-date`, `--dry-run`.
- `bin/cleanup_work_item_comments.dart` — удаление служебных комментариев `AI-оценка youtrack_timer`.
- Загрузка `.env` через `dotenv` / `EnvLoader`.

#### Конфигурация разработки

- FVM (`.fvmrc`), VS Code `launch.json` (Flutter Windows/Chrome, CLI).
- `.env.example`.

#### Тесты

- `youtrack_timer_test.dart`, `plan_recalculator_test.dart`, `time_distributor_test.dart`.
- `day_timeline_builder_test.dart`, `issue_assignee_parser_test.dart`, `issue_estimate_parser_test.dart`.
- `work_item_author_test.dart`, `work_item_comments_test.dart`, `date_utils_work_item_test.dart`.
- `youtrack_query_test.dart`, `youtrack_credentials_test.dart`, `log_sanitizer_test.dart`.
- `widget_test.dart`.

### Безопасность

- Токены не логируются в открытом виде.
- `.env` в `.gitignore`.
- Трёхуровневая защита от случайной записи (dry-run, диалог, submit guard).
