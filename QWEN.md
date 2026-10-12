# СОЛНЦЕМЕР (Solntsemer)

Приложение для отображения **истинного местного солнечного времени** по координатам наблюдателя.
Полное техническое задание — в `TODO.md` (27 функциональных требований, FR-01…FR-27).

## Идентификация

- **Название:** СОЛНЦЕМЕР / Solntsemer
- **Package id:** `dev.atom42.solntsemer`
- **Лицензия кода:** GPLv3 or later (см. `LICENSE`)
- **Целевые платформы:** Android (min SDK 26) + GNU/Linux desktop.

## Стек

- **Flutter:** 3.47.3 (stable, 2026-09-09) — установлен в `~/development/flutter`
- **Dart:** 3.13.3
- **Управление состоянием:** `flutter_riverpod` (MIT)
- **Астрономия:** `astronomia` (MIT, чистый Dart, реализация J. Meeus «Astronomical Algorithms» + VSOP87)
  — модули `eqtime`, `sidereal`, `solar`, `nutation`, `parallax`, `sunrise`, `deltat`, `julian`.
- **Локальное хранилище:** `shared_preferences` (BSD-3)
- **Форматирование:** `intl` (BSD-3)
- **Геолокация на Android:** собственный `MethodChannel` / `EventChannel` с нативным Kotlin,
  использующим `android.location.LocationManager` (без Google Play Services — ТЗ FR-05).
- **Запрещённые зависимости:** проприетарные карты, платные ключи, Google Play Services,
  закрытые SDK, тяжёлая аналитика, любые трекеры.

## MVP (этап 1) — завершён

Требования ТЗ FR-01..FR-07, FR-11, FR-13..FR-19, §12, §21 — реализованы

## Итерация 2 — завершена

CI, документация, встроенная таблица DUT1 (подробности в git-истории).

## Итерация 3 — завершена

Точность тика (FR-02), статус источника точки (FR-07), реалтайм-фиксы
(FR-06/14), DUT1 по сети (§12.5), настоящий README.

## Итерация 4 (текущая): карта, поиск, уведомление, виджет — ТЗ закрыт полностью

- **FR-08..FR-10 — экран карты** (`ui/map/map_screen.dart`, пакет
  `flutter_map` 8.3.2 BSD-3 + `latlong2` MIT): тайлы OSM с обязательной
  атрибуцией (SimpleAttributionWidget), перемещение/зум, долгое нажатие
  задаёт точку A/B (переключатель цели), маркеры A/B, координаты выбранной
  точки, кнопки «моё местоположение» и «ввести вручную» (FR-11).
  Без сети: баннер «тайлы не загрузятся», ручной ввод и расчёты работают
  офлайн (FR-10) — проверка сети HTTP HEAD к тайл-серверу.
- **FR-12 — поиск Nominatim** (`data/search/nominatim.dart`): открытые
  данные, HTTPS, User-Agent, лимит 1 запрос/сек (RateLimiter с инъекцией
  часов), атрибуция OSM в панели поиска, отключается в настройках
  и при отсутствии сети.
- **FR-20..FR-23 — постоянное уведомление** (Android):
  - Kotlin: `SolarTimeService` (foreground service, тип specialUse,
    канал IMPORTANCE_LOW без звука) + `NotificationPlugin`
    (MethodChannel: isPermitted/requestPermission/start/update/stop);
  - Dart: `data/notification/notification_repository.dart` +
    `NotificationController` (ui/providers.dart) — пока приложение живёт,
    пушит строки каждую секунду (те же числа, что на экране); если
    процесс убит — служба сама пересчитывает время нативно (fallback);
  - POST_NOTIFICATIONS запрашивается на Android 13+ (FR-23), при отказе
    функция отключается, приложение работает;
  - источник точки: A (текущее местоположение/ручная) или B (сравнение),
    ТЗ FR-22;
  - `_SystemBinder` в main.dart (через builder MaterialApp) держит
    активные подписки — Riverpod 3 паузит потоки без слушателей,
    а биндер смонтирован всегда, включая фон.
- **FR-24..FR-27 — виджет рабочего стола** (Android):
  - `SolartimeWidgetProvider` + `WidgetUpdater` + `WidgetConfigStore`:
    RemoteViews с временем ЧЧ:ММ (без секунд — ТЗ FR-25), смещением,
    подписью/координатами точки и восходом/заходом (местное время
    устройства) или полярным днём/ночью; размеры от 2×1 (targetCellWidth 4×1),
    ресайз;
  - обновления: «неточный» AlarmManager ~раз в минуту (без
    SCHEDULE_EXACT_ALARM, §16.3), плюс точная минутная синхронизация
    от работающей службы уведомления, плюс updatePeriodMillis=30 мин
    как страховка;
  - конфигурация в настройках приложения (FR-26): точка A / B /
    фиксированная, показ смещения и восхода/захода; фиксируется
    в SharedPreferences — виджет живёт без запущенного приложения;
  - FR-27: без точки/геолокации — последняя известная точка с пометкой
    «устарело» (динамические источники), касание открывает приложение.
- **Нативный калькулятор** `NativeSolarTime.kt` — упрощённый Meeus
  (низкоточные солнечные координаты + GMST + главные члены нутации):
  расхождение с astronomia ≤ 0.01 с по LAT, ≤ 40 с по восходу/заходу
  (сверка scripts/verify_native_solar.py по 5 точкам/4 моментам).
- **build.gradle.kts**: явная зависимость androidx.core-ktx (для
  NotificationCompat/ServiceCompat; ранее ActivityCompat подтягивался
  транзитивно), убран ndkVersion (нативного C++ нет), debug-сборки без
  стриппинга .so (не тянет 2+ ГБ NDK локально).
- Тесты: 110 (было 83): Nominatim (парсер/лимит/оффлайн), payload
  виджета (resolve/build), строки уведомления (FR-20 форматы).
- Проверка сборки: локально `:app:compileDebugKotlin` — BUILD SUCCESSFUL
  (Kotlin 9 файлов, ресурсы, смёрженный манифест с service/receiver/
  разрешениями); полная упаковка APK — в CI (в песочнице мало диска).

## Структура (ТЗ §15)

```
lib/
  main.dart
  core/
    astronomy/     # SolarCalculator: LAT, EoT, UTC-offset, rise/set, DUT1
    time/          # секундная граница, форматирование ЧЧ:ММ:СС / UTC-offset
    geo/           # GeoPoint (lat/lon WGS84), парсинг/валидация
  data/
    location/      # LocationRepository + Android platform channel
    dut1/          # таблица IERS + сетевое обновление (dut1_sync, finals_daily)
    search/        # Nominatim (поиск по названию, FR-12)
    notification/  # MethodChannel постоянного уведомления (FR-20..23)
    widget/        # MethodChannel виджета + payload (FR-24..27)
    settings/      # SharedPreferencesRepository + settingsProvider
  ui/
    home/          # главный экран: время, смещение, координаты, восход/заход
    map/           # экран карты OSM (flutter_map, FR-08..10)
    compare/       # сравнение A/B с разницей
    settings/      # интервалы, режим rise/set, DUT1, уведомление, виджет
```

Android (Kotlin): `LocationPlugin`, `NotificationPlugin`, `WidgetPlugin`,
`SolarTimeService`, `SolartimeWidgetProvider`, `WidgetUpdater`,
`WidgetConfigStore`, `NativeSolarTime`.

## Сборка и проверка

- `flutter doctor` — должен быть зелёным для Linux и Android toolchain.
- `flutter pub get`
- `flutter test` — все юнит-тесты (астрономия, форматирование, парсинг координат, DUT1-сеть, Nominatim, виджет/уведомление).
- `flutter analyze` — без warning/error.
- `flutter build linux` — собирает исполняемый файл для GNU/Linux (в песочнице нет cmake — собирает CI).
- Android: локально проверено `:app:compileDebugKotlin` (BUILD SUCCESSFUL;
  JDK 17 Temurin, SDK platform 36); полная упаковка APK — в CI.
- **CI**: `.github/workflows/release.yml` — при **push** (ветка по умолчанию) и вручную (`workflow_dispatch`)
  собирает GNU/Linux
  (`tar.gz`) и Android (`apk`, без AAB — Google Play не планируется) и публикует pre-release в
  GitHub Releases; перед сборкой — `flutter analyze` + `flutter test` + проверка на закрытые
  зависимости. Flutter в CI зафиксирован: 3.47.3 stable.

## Ключевые формулы

```
LMT  = UTC_h + λ/15
LAT  = LMT + E                       (через уравнение времени)
LAT  = (GAST + λ/15 − α_app) mod 24  (эквивалентная форма ТЗ §12.1)
ΔUTC = LAT − UTC_h                   (истинное смещение от UTC, часы)
```

`GAST`, `α_app`, `E` вычисляются через `astronomia` с учётом прецессии, нутации, аберрации,
световой задержки и топоцентрического параллакса. `DUT1` подмешивается в `jd_ut1 = jd_utc + DUT1/86400`
(на `jde` поправка пренебрежимо мала — ΔTT ≈ 0 при DUT1 ≤ 0.9 с).

## Git-конвенции

Коммит-сообщения — краткие, на русском, в стиле существующего журнала
(`Добавить: …`, `Исправить: …`, `Обновить: …`). Перед коммитом: `flutter analyze` + `flutter test`.
