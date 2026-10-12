# СОЛНЦЕМЕР (Solntsemer)

Кроссплатформенное приложение (Android + GNU/Linux), показывающее **истинное
местное солнечное время** по видимому положению Солнца над выбранной точкой:
текущее время, смещение от UTC, ближайшие восход/заход/полдень, сравнение
двух точек. Без проприетарных сервисов: астрономия считается на устройстве
по J. Meeus (пакет `astronomia`), геолокация — через системный
`LocationManager`, поправка DUT1 — из открытых данных IERS.

- Техническое задание: [`TODO.md`](TODO.md) (27 функциональных требований).
- Алгоритмы: [`ALGORITHMS.md`](ALGORITHMS.md).
- Приватность: [`PRIVACY.md`](PRIVACY.md). Лицензии: [`LICENSES.md`](LICENSES.md).
- Лицензия кода: **GPLv3 или новее**.

## Возможности

- Истинное солнечное время и смещение `UTC±ЧЧ:ММ:СС` для точки A (обновление
  каждую секунду, синхронизировано с секундной границей системных часов).
- Ближайшие восход/заход/полдень в местном времени с датой; полярный
  день/ночь; два режима: наблюдаемый (−0.833°) и геометрический (0°).
- Точка A: автоматическая геолокация (GPS/сеть, фильтр анти-дрожания)
  или ручной ввод координат; статус источника и «Обновлено ЧЧ:ММ:СС · ±N м».
- Сравнение точек A/B с нормализованной разницей в [-12ч, +12ч].
- DUT1 (UT1−UTC): встроенная таблица IERS 2015–2027 + фоновое обновление
  по сети (finals2000A.daily, HTTPS, кэш на сутки; можно выключить).
  Без сети приложение полностью работает офлайн.

## Сборка

Требуется Flutter stable (проверено на 3.47.x, Dart ≥ 3.13.3) и для
Android — JDK 17.

```bash
flutter pub get
flutter test          # 83 теста
flutter analyze       # без замечаний

# GNU/Linux (GTK 3, cmake, ninja, clang):
flutter build linux --release
# результат: build/linux/x64/release/bundle/solntsemer

# Android APK (minSdk 26, arm64-v8a + armeabi-v7a + x86_64):
flutter build apk --release
# результат: build/app/outputs/flutter-apk/app-release.apk
```

APK подписывается отладочным ключом Flutter (для прямой установки достаточно;
релизная подпись не настроена). На устройствах без Google-сервисов
приложение работает: геолокация через `android.location.LocationManager`.

## CI / Releases

`.github/workflows/release.yml`: при каждом **push** —
`analyze` + `test`, сборка GNU/Linux (tar.gz) и Android APK, публикация
в GitHub Releases как **pre-release** (тег и имя файла — из `pubspec.yaml`;
ассеты перезаливаются). Ручной запуск — с выбором версии и флагов.

## Данные и атрибуция

- Астрономия: `astronomia` (MIT) — реализация J. Meeus
  «Astronomical Algorithms» + VSOP87.
- DUT1: IERS Bulletin A `finals2000A` (finals.all), зеркала
  `maia.usno.navy.mil`, `hpiers.obspm.fr` — открытые данные, HTTPS.
- Карты (когда появятся, ТЗ FR-08): © OpenStreetMap contributors.

## Структура

```
lib/
  core/       # расчёты: астрономия, время, гео-точки
  data/       # источники: геолокация (Android channel), DUT1, настройки
  ui/         # экраны: главный, сравнение, настройки
```
