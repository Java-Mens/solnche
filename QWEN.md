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

## MVP (этап 1 — текущая итерация)

В scope входят требования ТЗ:

- **FR-01..FR-04** — отображение истинного времени, обновление раз в секунду, смещение от UTC,
  независимость от часовых поясов устройства.
- **FR-05..FR-07** — геолокация на Android через `LocationManager` (15 с по умолчанию),
  graceful degradation при запрете.
- **FR-11** — ручной ввод координат (WGS84).
- **FR-13..FR-15** — сравнение двух точек (карточки A/B, нормализованная разница в `[-12ч,+12ч]`).
- **FR-16..FR-19** — истинный восход/заход/полдень, два режима (-0.833° и 0°), корректные полярные случаи.
- **§12 астрономия** — точность ±1 с, GAST+α-формула, DUT1 (встроенная таблица или fallback на UTC).
- **§14 Экран 1 + Экран 3 + Экран 4** — главный экран, сравнение, настройки (минимальные).
- **§21** — форматирование ЧЧ:ММ:СС, UTC±ЧЧ:ММ:СС, ±ЧЧ:ММ:СС.
- **§22 критерии приёмки 1-6, 9-11** — без Android-виджета и уведомления.

Отложено на следующие итерации:

- **FR-08..FR-10, FR-12** — OSM-карта и поиск (Nominatim).
- **FR-20..FR-23** — foreground service + постоянное уведомление.
- **FR-24..FR-27** — виджет рабочего стола Android.
- README с инструкциями сборки.

Уже сделано: GitHub Actions (`.github/workflows/release.yml`), `PRIVACY.md`, `LICENSES.md`, `ALGORITHMS.md`.

## Структура (ТЗ §15)

```
lib/
  main.dart
  core/
    astronomy/     # SolarCalculator: LAT, EoT, UTC-offset, rise/set, DUT1
    time/          # tick (1 Hz ticker), форматирование ЧЧ:ММ:СС / UTC-offset
    geo/           # GeoPoint (lat/lon WGS84), парсинг/валидация
  data/
    location/      # LocationRepository + Android platform channel
    dut1/          # Dut1Provider: встроенная таблица + fallback
    settings/      # SharedPreferencesRepository
  ui/
    home/          # главный экран: время, смещение, координаты, восход/заход
    compare/       # сравнение A/B с разницей
    settings/      # интервалы, режим rise/set, DUT1-source
    widgets/       # переиспользуемые виджеты
  app.dart         # ProviderScope + MaterialApp + роутинг
```

## Сборка и проверка

- `flutter doctor` — должен быть зелёным для Linux и Android toolchain.
- `flutter pub get`
- `flutter test` — все юнит-тесты (астрономия, форматирование, парсинг координат).
- `flutter analyze` — без warning/error.
- `flutter build linux` — собирает исполняемый файл для GNU/Linux (primary target проверки в этой сессии).
- Локальные Android-сборки (APK) **не выполняются** в этой итерации по решению пользователя;
  Android SDK установлен в `~/Android/Sdk` (если добавится), но `flutter build apk` локально не запускается.
- **CI**: `.github/workflows/release.yml` (ручной запуск `workflow_dispatch`) собирает GNU/Linux
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
