# Модель данных и инварианты

Доменные типы отделены от записей SwiftData и сетевых DTO. Идентификаторы стабильны; даты создания, изменения и версии записываются явно. Масса хранится в кг, рост в см; форматирование и будущая конвертация единиц выполняются на границе интерфейса.

| Сущность | Основные поля и назначение |
| --- | --- |
| UserProfile | id, displayName?, heightCm, currentGoal, experience?, constraints?, selectedPersonaID, createdAt |
| BodyMeasurement | id, profileID, measuredAt, weightKg; исходная точка истории и последующие записи |
| OnboardingDraft | шаг, частично введённые поля, updatedAt; не считается готовым профилем |
| TrainingPreferences | visitsPerWeek, sessionDurationMinutes, equipmentIDs, revision |
| ScheduleRule | id, profileID, weekday, localTime, timezonePolicy, effectiveFrom, revision |
| ScheduleException | date, тип pause/move/cancel, originalSessionID?, replacementDate? |
| CoachPersona | id, name, avatarAsset, toneID, messageCatalogVersion; не содержит тренировочных правил |
| WeeklyPlan | id, profileID, weekStartLocalDate, timezoneID, revision, inputRevision, generatorVersion, corpusVersion?, origin, status |
| PlannedSession | id, planID, localDate, scheduledAt, timezoneID, templateSnapshot, status |
| ExerciseDefinition | id, name, equipment, movementPattern, muscleGroups, instructions, sourceID |
| WorkoutTemplate | id, version, orderedBlocks, suitabilityTags, sourceID, authorship |
| ExercisePrescription | exerciseID, snapshotName, sets, repetitionsRange?, durationSeconds?, restSeconds?, loadGuidance? |
| WorkoutSession | id, plannedSessionID, startedAt, finishedAt?, state, perceivedEffort?, note? |
| SetLog | id, sessionID, exerciseInstanceID, index, reps?, loadKg?, duration?, completedAt? |
| CoachMessage | id, personaID, role, text, origin, createdAt; история необязательна для локальных карточек |
| NotificationPreferences | enabled, leadTimeMinutes, quietHours, tone, previewPrivacy |
| Achievement | id, ruleVersion, awardedAt, sourceSessionIDs; повторная выдача исключается |
| AppSettings | theme, locale, units, aiMode, consentVersion?; ключа здесь нет |

## Связи и состояния

Профиль → измерения, расписание, недельные планы. План → запланированные занятия. Запланированное занятие → максимум одна активная/завершённая сессия выполнения. Сессия → подходы. Шаблон копируется в snapshot занятия: изменения каталога не меняют старую историю.

Plan: draft → ready → superseded. Ошибочная генерация не активируется. PlannedSession: scheduled → inProgress → completed; scheduled → missed или cancelled. Перенос меняет дату того же логического занятия с записью изменения. Сессия выполнения: active → paused → active → completed, либо abandoned. Прерванная сессия не считается завершённой автоматически.

## Правила целостности

- visitsPerWeek равно числу уникальных выбранных дней. Для первого интерфейса 1–7; частота сама по себе не обещает подходящую нагрузку. Невозможность реального плана возвращается явно.
- План содержит ревизию входных параметров. Устаревший ответ генератора не заменяет новый план.
- Завершённая история неизменна при смене цели, тренера, расписания или алгоритма.
- Изменение будущего плана, активной ревизии и исключений выполняется атомарно; внешние уведомления согласуются после сохранения.
- Повторное завершение с тем же sessionID возвращает прежний результат, не добавляет прогресс второй раз.
- У каждого плана origin: mock / rules / assisted; после MVP — также trainerAssigned. Демонстрационные данные не смешиваются с настоящей статистикой.
- Рост и вес валидируются на число, единицы и допустимость ввода. Точные продуктовые диапазоны закрепляются до реализации, а не выдаются за медицинские нормы.
- Измерение веса не перезаписывает прошлые измерения. Исправление конкретной записи доступно отдельно.

## Время

Неделя в первом интерфейсе начинается в понедельник. Повторяющееся расписание задаётся местным временем устройства; каждое созданное занятие сохраняет часовой пояс и абсолютную дату. При смене часового пояса пользователь подтверждает пересчёт будущих занятий, история сохраняет исходные даты.

Для перевода часов: отсутствующее местное время переносим на ближайшее существующее время того же дня, повторяющееся — на первое вхождение; изменение показываем в плане. Серия считается по дате занятия в его сохранённой временной зоне. Занятие, начатое до полуночи и завершённое после, относится к своему плановому дню.

## Версии и хранение

С первой схемы задаём SchemaV1 и стратегию миграций. Версия схемы БД, версия JSON-корпуса и версия алгоритма — разные значения. Корпус и fixture содержат schemaVersion. Импорт некорректного документа не изменяет текущий каталог. При добавлении синхронизации отдельно проектируем конфликты; текущая архитектура не обещает бесплатную синхронизацию.

## Авторство и будущие роли

В MVP authorship хранит тип источника bundled/imported и sourceID; реального автора исходного корпуса не подменяем аккаунтом приложения. После MVP добавляется account-авторство с authorAccountID. generatorVersion нужен сгенерированному плану; для назначения человека сохраняем версию источника, не выдумывая версию алгоритма.

Следующие сущности — проект расширения, а не обязательные таблицы MVP:

| Сущность | Назначение |
| --- | --- |
| Account | id, roles, status; идентичность отдельно от физического профиля |
| TrainerProfile | accountID, displayName, biography?, avatar; профиль живого тренера |
| TrainerClientRelationship | id, trainerAccountID, clientAccountID, status, sharedScopes, acceptedAt, endedAt? |
| Invitation | id, inviterID, expiresAt, status; одноразовое принятие связи |
| ContentImport | id, authorAccountID, source, state, issues, draftID?, requestID |
| ProgramTemplate | id, authorAccountID, version, orderedWorkoutReferences; повторно используемая программа |
| Assignment | id, relationshipID, clientAccountID, authorAccountID, clientLocalDate, timezoneID, snapshot, revision, status, requestID |
| AssignmentFeedback | id, assignmentID, sessionID?, authorAccountID, text, createdAt |

Assignment проходит draft → published → superseded/cancelled. Выполнение и факт получения хранятся отдельно от состояния публикации. PlannedSession получает assignmentID? и sourceRevision?; UserProfile — ownerAccountID? при регистрации. CoachPersona не имеет прав доступа, а TrainerProfile не заменяет каталог виртуальных персонажей.

Контент библиотеки принадлежит автору; персональное назначение относится к конкретной связи; фактический WorkoutSession принадлежит клиенту. Назначенный snapshot сохраняется в истории независимо от дальнейшего редактирования шаблона. Результаты нескольких клиентов не объединяются по templateID.

## Реализованный срез (1 октября 2026)

OnboardingDraft содержит пол, рост/вес как вводимые строки, цель, опыт, длительность, пожелания, дни недели, время и BodyLimitation. LocalProfile оборачивает подтверждённую анкету со стабильным ID и датами. Каждое ограничение содержит zone, side, kind, discomfortLevel?, avoidMovements и notes. Неуказанный уровень не интерпретируется как отсутствие ограничения.

**Хранилище.** Модель выше описывает целевую нормализованную схему. Сейчас SwiftData хранит единственную модель `LocalProfileRecord` (`ProfileSchemaV1`): уникальный `key` и `payload` — JSON документа. Весь слой записи скрыт за протоколом `DocumentStore` (`load`, `save`, `remove`, `removeAll`); `SwiftDataProfileRepository` его реализует, в тестах подставляется хранилище в памяти. Документ читается и пишется целиком. Модели `Domain/*` от SwiftData не зависят.

| Ключ | Документ | Кто пишет |
| --- | --- | --- |
| `draft` | Черновик анкеты | Онбординг |
| `profile` | Подтверждённый профиль | Онбординг, редактирование |
| `workoutLogs` | Журнал тренировок: подходы (вес, повторы или секунды и тип `kind`: рабочий, разминка, до отказа, дроп-сет), `sessionKey` слота, `plannedSets`, `plannedExerciseIDs` | Завершение тренировки, удаление из истории |
| `workoutLogs.recovered` | Тренировки, записанные, пока основной журнал не читался; сливаются обратно | Завершение тренировки |
| `activeSession` | Снимок незавершённой тренировки | Любое изменение сессии |
| `schedule` | Ревизии дней, переносы, пропуски, паузы, замены упражнений `swaps` | Расписание |
| `weights` | Взвешивания (одно в день) | Вес тела |
| `coach` | Выбранный тренер | Профиль |
| `reminders` | Настройки напоминаний | Профиль |
| `achievements` | Выданные достижения с версией правил | Прогресс |

**Совместимость и сбои.** Новые поля документов читаются с запасными значениями (собственные декодеры у `WorkoutLog`, `ReminderSettings` и др.), поэтому данные, записанные прежней версией, продолжают читаться. При первом запуске после обновления расписание получает первую ревизию из профиля, а журнал веса — первую запись из профиля; прежняя история не придумывается. Документ, который не удалось прочитать, не удаляется и не перезаписывается молча: для журнала тренировок есть путь `workoutLogs.recovered`, остальные ошибки показываются на экране.

**Время.** День занятия — `DayKey`, строка «гггг-мм-дд» в локальном календаре. Идентичность запланированного занятия — слот (`DayKey` дня, на который оно назначено расписанием); перенос меняет день, но не слот. Мгновения (начало и конец тренировки, конец отдыха) хранятся как даты.

**Экспорт.** `ExportBundle` (формат `maestro-felix-export`, версия 1): профиль, тренировки, вес, расписание, достижения, тренер, напоминания, дата выгрузки; JSON, даты ISO 8601. Снимок незавершённой тренировки и черновик в файл не входят. Импорта нет.

**Не сделано.** Нормализованные сущности для тренеров, аккаунтов и назначений (выше) остаются проектом расширения. Миграции схемы SwiftData пока пустые (`stages: []`): версия одна.

## Уточнение выбора расписания

По последней обратной связи выбираются только дни недели. Число посещений вычисляется из выбранных дней и отдельно не запрашивается. Пустой выбор не позволяет завершить настройку. Это заменяет прежнее требование согласовывать два отдельных поля частоты и дней.
