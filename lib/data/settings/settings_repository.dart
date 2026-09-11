// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/astronomy/solar_calculator.dart';
import '../../core/geo/geo_point.dart';

/// Хранение настроек приложения в SharedPreferences.
class SettingsRepository {
  static const _kPointA = 'point_a';
  static const _kPointB = 'point_b';
  static const _kSunriseMode = 'sunrise_mode';
  static const _kLocationInterval = 'location_interval_s';
  static const _kTimeUpdateInterval = 'time_update_interval_s';

  final SharedPreferences _prefs;

  SettingsRepository(this._prefs);

  static Future<SettingsRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsRepository(prefs);
  }

  GeoPoint? getPointA() => _readPoint(_kPointA);

  GeoPoint? getPointB() => _readPoint(_kPointB);

  Future<void> setPointA(GeoPoint? p) => _writePoint(_kPointA, p);

  Future<void> setPointB(GeoPoint? p) => _writePoint(_kPointB, p);

  SunriseMode get sunriseMode {
    final v = _prefs.getString(_kSunriseMode);
    return v == 'geometric' ? SunriseMode.geometric : SunriseMode.observed;
  }

  Future<void> setSunriseMode(SunriseMode mode) =>
      _prefs.setString(_kSunriseMode, mode.name);

  int get locationIntervalSeconds =>
      _prefs.getInt(_kLocationInterval) ?? 15;

  Future<void> setLocationIntervalSeconds(int s) =>
      _prefs.setInt(_kLocationInterval, s);

  int get timeUpdateIntervalSeconds =>
      _prefs.getInt(_kTimeUpdateInterval) ?? 1;

  Future<void> setTimeUpdateIntervalSeconds(int s) =>
      _prefs.setInt(_kTimeUpdateInterval, s);

  GeoPoint? _readPoint(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    return GeoPoint.tryParse(raw);
  }

  Future<void> _writePoint(String key, GeoPoint? p) {
    if (p == null) return _prefs.remove(key);
    return _prefs.setString(key, '${p.lat},${p.lon}');
  }
}
