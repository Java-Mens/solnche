// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/astronomy/solar_calculator.dart';
import '../../core/geo/geo_point.dart';
import '../dut1/dut1_cache.dart';

/// Хранение настроек приложения в SharedPreferences.
class SettingsRepository {
  static const _kPointA = 'point_a';
  static const _kPointB = 'point_b';
  static const _kSunriseMode = 'sunrise_mode';
  static const _kLocationInterval = 'location_interval_s';
  static const _kTimeUpdateInterval = 'time_update_interval_s';
  static const _kPointAManual = 'point_a_manual';
  static const _kDut1NetworkEnabled = 'dut1_network_enabled';
  static const _kDut1CacheEntries = 'dut1_cache_entries';
  static const _kDut1CacheAt = 'dut1_cache_fetched_at';
  static const _kDut1CacheSource = 'dut1_cache_source';

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

  /// `true`, если точка A задана вручную и не должна перезаписываться
  /// автоматической геолокацией (в том числе устаревшим getLastKnown
  /// при следующем запуске приложения).
  bool get pointAManual => _prefs.getBool(_kPointAManual) ?? false;

  Future<void> setPointAManual(bool v) => _prefs.setBool(_kPointAManual, v);

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

  // ── DUT1 по сети (ТЗ §12.5, §13.3) ─────────────────────────────────────

  /// Разрешено ли обновление DUT1 по сети. По умолчанию включено.
  bool get dut1NetworkEnabled => _prefs.getBool(_kDut1NetworkEnabled) ?? true;

  Future<void> setDut1NetworkEnabled(bool v) =>
      _prefs.setBool(_kDut1NetworkEnabled, v);

  /// Кэш DUT1, скачанный по сети (может быть null — тогда работает
  /// встроенная таблица).
  Dut1CacheData? getDut1Cache() {
    final raw = _prefs.getString(_kDut1CacheEntries);
    final atMs = _prefs.getInt(_kDut1CacheAt);
    if (raw == null || atMs == null) return null;
    final entries = decodeDut1Cache(raw);
    if (entries == null) return null;
    return Dut1CacheData(
      entries: entries,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(atMs, isUtc: true),
      source: _prefs.getString(_kDut1CacheSource) ?? '',
    );
  }

  Future<void> setDut1Cache({
    required List<(double, double)> entries,
    required DateTime fetchedAt,
    required String source,
  }) async {
    await _prefs.setString(
        _kDut1CacheEntries, encodeDut1Cache(entries));
    await _prefs.setInt(
        _kDut1CacheAt, fetchedAt.millisecondsSinceEpoch);
    await _prefs.setString(_kDut1CacheSource, source);
  }

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
