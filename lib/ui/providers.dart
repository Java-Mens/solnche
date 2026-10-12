// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/astronomy/solar_calculator.dart';
import '../core/geo/geo_point.dart';
import '../core/time/second_boundary.dart';
import '../data/dut1/dut1_provider.dart';
import '../data/location/location_repository.dart';
import '../data/settings/settings_provider.dart';
import '../data/settings/settings_repository.dart';

// Репозиторий настроек и источник DUT1 вынесены в data-слой
// (data/settings/settings_provider.dart, data/dut1/dut1_provider.dart) —
// переэкспортируем, чтобы существующие импорты ui/providers.dart работали.
export '../data/dut1/dut1_provider.dart' show dut1Provider;
export '../data/settings/settings_provider.dart' show settingsProvider;

/// Провайдер источника геолокации.
final locationProvider = Provider<LocationRepository>((ref) {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return AndroidLocationRepository();
  }
  return const UnsupportedLocationRepository();
});

// ── Точка A ──────────────────────────────────────────────────────────────────

final pointAProvider = NotifierProvider<PointANotifier, GeoPoint?>(PointANotifier.new);

/// Точка A с автоматическим определением местоположения.
///
/// Поведение:
/// - в режиме «авто» (по умолчанию) точка обновляется по данным GPS/сети
///   с фильтрацией (возраст, точность, порог смещения);
/// - ручной ввод координат переключает точку в ручной режим: слежение
///   останавливается, и сохранённые координаты не перезаписываются
///   ни потоком GPS, ни устаревшим кэшем getLastKnown при перезапуске;
/// - [startAutoLocation] возвращает точку в автоматический режим.
class PointANotifier extends Notifier<GeoPoint?> {
  StreamSubscription? _sub;

  /// Фильтр «живых» фиксов из потока GPS/сети.
  static const _streamFilter = FixFilter(
    maxAge: Duration(seconds: 90),
    maxAccuracyMeters: 100,
    minMoveMeters: 25,
  );

  /// Фильтр для getLastKnown при старте: допускаем более старый кэш,
  /// чтобы сразу показать хоть что-то (свежий фикс уточнит позицию).
  static const _lastKnownFilter = FixFilter(
    maxAge: Duration(minutes: 15),
    maxAccuracyMeters: 2500,
    minMoveMeters: 25,
  );

  @override
  GeoPoint? build() {
    final settings = ref.read(settingsProvider);
    final location = ref.read(locationProvider);
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });
    if (!settings.pointAManual) {
      unawaited(_initAutoLocation(settings, location));
    }
    return settings.getPointA();
  }

  Future<void> _initAutoLocation(
    SettingsRepository settings,
    LocationRepository location, {
    bool forcePermissionRequest = false,
  }) async {
    try {
      var status = await location.checkStatus();
      if (status == LocationStatus.permissionDenied || forcePermissionRequest) {
        status = await location.requestPermission();
      }
      if (status != LocationStatus.available) return;

      final last = await location.getLastKnown();
      if (last != null && state == null) {
        if (_lastKnownFilter.accept(last, null, DateTime.now().toUtc())) {
          state = last.point;
          ref.read(pointAFixProvider.notifier).state = last;
          settings.setPointA(last.point);
        }
      }

      await _sub?.cancel();
      _sub = location
          .watch(intervalSeconds: settings.locationIntervalSeconds)
          .listen((fix) {
        if (!_streamFilter.accept(fix, state, DateTime.now().toUtc())) {
          return;
        }
        if (fix.point == state) return;
        state = fix.point;
        ref.read(pointAFixProvider.notifier).state = fix;
        settings.setPointA(fix.point);
      });
    } finally {
      // Статус источника точки A изменился — пересчитать (ТЗ FR-07).
      ref.invalidate(pointASourceProvider);
    }
  }

  /// Ручной ввод координат: останавливаем автоопределение и фиксируем
  /// ручной режим в настройках.
  Future<void> setPoint(GeoPoint? p) async {
    await _sub?.cancel();
    _sub = null;
    try {
      await ref.read(locationProvider).stopWatching();
    } catch (_) {
      // платформа без геолокации
    }
    state = p;
    final settings = ref.read(settingsProvider);
    await settings.setPointAManual(p != null);
    await settings.setPointA(p);
    // Ручной режим: индикация фикса больше не актуальна.
    ref.read(pointAFixProvider.notifier).state = null;
    // Точка стала ручной — обновить статус (ТЗ FR-07).
    ref.invalidate(pointASourceProvider);
  }

  /// Возвращает точку A в автоматический режим (кнопка «Моё местоположение»).
  Future<void> startAutoLocation() async {
    final settings = ref.read(settingsProvider);
    await settings.setPointAManual(false);
    await _initAutoLocation(settings, ref.read(locationProvider),
        forcePermissionRequest: true);
  }
}

// ── Статус источника точки A (ТЗ FR-07) ─────────────────────────────────

/// Откуда в текущий момент берётся точка A — для индикации в интерфейсе.
enum PointASource {
  /// Задана вручную, геолокация не используется.
  manual,

  /// Определяется автоматически, геолокация доступна.
  tracking,

  /// Геолокация недоступна — используется выбранная точка.
  geoUnavailable,
}

final pointASourceProvider = FutureProvider<PointASource>((ref) async {
  final settings = ref.watch(settingsProvider);
  if (settings.pointAManual) return PointASource.manual;
  final location = ref.watch(locationProvider);
  final status = await location.checkStatus();
  return status == LocationStatus.available
      ? PointASource.tracking
      : PointASource.geoUnavailable;
});

/// Последний принятый фикс геолокации точки A (ТЗ FR-06/FR-14):
/// момент, точность и провайдер — для индикации «координаты обновляются
/// в реалтайме» на главном экране.
final pointAFixProvider =
    NotifierProvider<PointAFixNotifier, LocationFix?>(PointAFixNotifier.new);

class PointAFixNotifier extends Notifier<LocationFix?> {
  @override
  LocationFix? build() => null;
}

// ── Точка B ──────────────────────────────────────────────────────────────────

final pointBProvider = NotifierProvider<PointBNotifier, GeoPoint?>(PointBNotifier.new);

class PointBNotifier extends Notifier<GeoPoint?> {
  @override
  GeoPoint? build() {
    return ref.read(settingsProvider).getPointB();
  }

  Future<void> setPoint(GeoPoint? p) async {
    state = p;
    await ref.read(settingsProvider).setPointB(p);
  }
}

// ── Режим восхода/захода ─────────────────────────────────────────────────────

final sunriseModeProvider = NotifierProvider<SunriseModeNotifier, SunriseMode>(SunriseModeNotifier.new);

class SunriseModeNotifier extends Notifier<SunriseMode> {
  @override
  SunriseMode build() {
    return ref.read(settingsProvider).sunriseMode;
  }

  Future<void> setMode(SunriseMode mode) async {
    state = mode;
    await ref.read(settingsProvider).setSunriseMode(mode);
  }
}

/// Пустой снимок для отсутствующей точки.
SolarSnapshot _emptySnapshot() => SolarSnapshot(
      lat: Duration.zero,
      utcOffset: Duration.zero,
      equationOfTime: Duration.zero,
      dut1Seconds: 0,
      dut1Precise: false,
      nextSunriseUtc: null,
      nextSunsetUtc: null,
      solarNoonUtc: null,
      polarDay: false,
      polarNight: false,
    );

/// Периодический поток с немедленным первым значением (без «пустого»
/// интервала ожидания при пересоздании провайдера).
///
/// Тики выровнены по секундной границе системных часов (ТЗ FR-02):
/// при интервале 1 с значения выдаются точно на целых секундах,
/// при больших интервалах — на целых секундах, кратных интервалу.
Stream<SolarSnapshot> _ticker(
    Duration interval, SolarSnapshot Function() compute) async* {
  yield compute();
  var ticksLeft = interval.inSeconds;
  while (true) {
    await Future.delayed(
        Duration(milliseconds: delayToNextSecondBoundary(DateTime.now())));
    if (--ticksLeft > 0) continue;
    ticksLeft = interval.inSeconds;
    yield compute();
  }
}

// ── Солнечный снимок (точка A) ───────────────────────────────────────────────

final solarSnapshotProvider = StreamProvider<SolarSnapshot>((ref) {
  final dut1 = ref.watch(dut1Provider);
  final mode = ref.watch(sunriseModeProvider);
  final settings = ref.watch(settingsProvider);
  final point = ref.watch(pointAProvider);

  final calc = SolarCalculator(dut1Source: dut1, sunriseMode: mode);
  final interval = Duration(seconds: settings.timeUpdateIntervalSeconds);

  return _ticker(interval, () {
    if (point == null) return _emptySnapshot();
    return calc.compute(point, DateTime.now().toUtc());
  });
});

// ── Солнечный снимок (точка B) ───────────────────────────────────────────────

final solarSnapshotBProvider = StreamProvider<SolarSnapshot>((ref) {
  final dut1 = ref.watch(dut1Provider);
  final mode = ref.watch(sunriseModeProvider);
  final settings = ref.watch(settingsProvider);
  final point = ref.watch(pointBProvider);

  final calc = SolarCalculator(dut1Source: dut1, sunriseMode: mode);
  final interval = Duration(seconds: settings.timeUpdateIntervalSeconds);

  return _ticker(interval, () {
    if (point == null) return _emptySnapshot();
    return calc.compute(point, DateTime.now().toUtc());
  });
});
