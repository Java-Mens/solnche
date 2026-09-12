// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/astronomy/solar_calculator.dart';
import '../core/geo/geo_point.dart';
import '../data/dut1/dut1_source.dart';
import '../data/location/location_repository.dart';
import '../data/settings/settings_repository.dart';

/// Провайдер репозитория настроек.
final settingsProvider = Provider<SettingsRepository>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

/// Провайдер источника геолокации.
final locationProvider = Provider<LocationRepository>((ref) {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return AndroidLocationRepository();
  }
  return const UnsupportedLocationRepository();
});

/// Провайдер источника DUT1.
final dut1Provider = Provider<Dut1Source>((ref) {
  return const NoDut1Source();
});

// ── Точка A ──────────────────────────────────────────────────────────────────

final pointAProvider = NotifierProvider<PointANotifier, GeoPoint?>(PointANotifier.new);

class PointANotifier extends Notifier<GeoPoint?> {
  StreamSubscription? _sub;

  @override
  GeoPoint? build() {
    final settings = ref.read(settingsProvider);
    final location = ref.read(locationProvider);
    ref.onDispose(() => _sub?.cancel());
    _init(settings, location);
    return settings.getPointA();
  }

  Future<void> _init(SettingsRepository settings, LocationRepository location) async {
    final status = await location.checkStatus();
    if (status == LocationStatus.available) {
      final fix = await location.getLastKnown();
      if (fix != null) {
        state = fix.point;
        await settings.setPointA(fix.point);
      }
      _sub = location.watch(intervalSeconds: settings.locationIntervalSeconds).listen((fix) {
        state = fix.point;
        settings.setPointA(fix.point);
      });
    }
  }

  Future<void> setPoint(GeoPoint? p) async {
    await _sub?.cancel();
    state = p;
    await ref.read(settingsProvider).setPointA(p);
  }
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

// ── Солнечный снимок (точка A) ───────────────────────────────────────────────

final solarSnapshotProvider = StreamProvider<SolarSnapshot>((ref) {
  final dut1 = ref.watch(dut1Provider);
  final mode = ref.watch(sunriseModeProvider);
  final settings = ref.watch(settingsProvider);

  final calc = SolarCalculator(dut1Source: dut1, sunriseMode: mode);
  final interval = Duration(seconds: settings.timeUpdateIntervalSeconds);

  return Stream.periodic(interval, (_) {
    final point = ref.read(pointAProvider); // read, не watch
    if (point == null) return _emptySnapshot();
    return calc.compute(point, DateTime.now().toUtc());
  });
});

// ── Солнечный снимок (точка B) ───────────────────────────────────────────────

final solarSnapshotBProvider = StreamProvider<SolarSnapshot>((ref) {
  final dut1 = ref.watch(dut1Provider);
  final mode = ref.watch(sunriseModeProvider);
  final settings = ref.watch(settingsProvider);

  final calc = SolarCalculator(dut1Source: dut1, sunriseMode: mode);
  final interval = Duration(seconds: settings.timeUpdateIntervalSeconds);

  return Stream.periodic(interval, (_) {
    final point = ref.read(pointBProvider); // read, не watch
    if (point == null) return _emptySnapshot();
    return calc.compute(point, DateTime.now().toUtc());
  });
});
