// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/geo/geo_point.dart';

/// Статус доступности геолокации.
enum LocationStatus {
  /// Геолокация доступна и разрешение выдано.
  available,

  /// Разрешение не выдано.
  permissionDenied,

  /// Системная геолокация выключена.
  serviceDisabled,

  /// Платформа не поддерживает геолокацию (Linux desktop).
  unsupported,

  /// Неизвестно / ещё не проверялось.
  unknown,
}

/// Позиция с метаданными.
class LocationFix {
  final GeoPoint point;

  /// Момент фиксации (UTC).
  final DateTime timestampUtc;

  /// Радиус точности в метрах (если известен).
  final double? accuracyMeters;

  /// Источник: `gps`, `network`, `passive`, `fused`, …
  final String? provider;

  const LocationFix({
    required this.point,
    required this.timestampUtc,
    this.accuracyMeters,
    this.provider,
  });

  /// Возраст фикса относительно [now].
  Duration age(DateTime now) => now.difference(timestampUtc);
}

/// Абстракция источника геолокации.
abstract class LocationRepository {
  Future<LocationStatus> checkStatus();

  /// Запрашивает разрешение у пользователя (диалог системы, если нужно).
  Future<LocationStatus> requestPermission();

  Future<LocationFix?> getLastKnown();

  Stream<LocationFix> watch({required int intervalSeconds});

  Future<void> stopWatching();
}

/// Политика приёма фиксов геолокации.
///
/// Без фильтрации координаты «прыгают»: GPS- и сетевой провайдеры
/// присылают оценки с разной точностью (сотни метров — единицы
/// километров), и каждая из них напрямую попадала в интерфейс.
class FixFilter {
  /// Отбрасывать фиксы старше этого возраста.
  final Duration maxAge;

  /// Отбрасывать фиксы с точностью хуже этой. Первый фикс (когда точки
  /// ещё нет) принимается всегда — координаты с точностью 2 км лучше,
  /// чем их полное отсутствие.
  final double maxAccuracyMeters;

  /// Обновлять точку только после смещения минимум на это расстояние
  /// (метры). Меньшие дрожания GPS игнорируются.
  final double minMoveMeters;

  const FixFilter({
    this.maxAge = const Duration(seconds: 90),
    this.maxAccuracyMeters = 100,
    this.minMoveMeters = 25,
  });

  /// Решает, принимать ли [fix] при текущей точке [current] (может быть null).
  bool accept(LocationFix fix, GeoPoint? current, DateTime now) {
    if (!fix.point.isValid) return false;
    if (fix.age(now).abs() > maxAge) return false;
    final acc = fix.accuracyMeters;
    if (current == null) return true;
    if (acc != null && acc > maxAccuracyMeters) return false;
    return distanceMeters(fix.point, current) >= minMoveMeters;
  }

  /// Расстояние между точками в метрах (плоская аппроксимация —
  /// достаточна для порогов в десятки метров).
  static double distanceMeters(GeoPoint a, GeoPoint b) {
    const mPerDegLat = 111320.0;
    final mPerDegLon =
        111320.0 * math.cos(a.latRad + (b.latRad - a.latRad) / 2);
    final dy = (a.lat - b.lat) * mPerDegLat;
    final dx = (a.lon - b.lon) * mPerDegLon;
    return math.sqrt(dx * dx + dy * dy);
  }
}

/// Реализация для Android через MethodChannel + EventChannel.
class AndroidLocationRepository implements LocationRepository {
  static const _methodChannel =
      MethodChannel('dev.atom42.solntsemer/location');
  static const _eventChannel =
      EventChannel('dev.atom42.solntsemer/location_stream');

  StreamSubscription? _sub;
  final _controller = StreamController<LocationFix>.broadcast();

  @override
  Future<LocationStatus> checkStatus() async {
    try {
      final result = await _methodChannel.invokeMethod<String>('checkStatus');
      return _parseStatus(result);
    } on PlatformException {
      return LocationStatus.unknown;
    }
  }

  @override
  Future<LocationStatus> requestPermission() async {
    try {
      final result =
          await _methodChannel.invokeMethod<String>('requestPermission');
      return _parseStatus(result);
    } on PlatformException {
      return LocationStatus.unknown;
    }
  }

  @override
  Future<LocationFix?> getLastKnown() async {
    try {
      final map =
          await _methodChannel.invokeMapMethod<String, dynamic>('getLastKnown');
      if (map == null) return null;
      return _parseFix(map);
    } on PlatformException {
      return null;
    }
  }

  @override
  Stream<LocationFix> watch({required int intervalSeconds}) {
    _sub?.cancel();
    _sub = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final fix = _parseFix(Map<String, dynamic>.from(event));
          if (fix != null) _controller.add(fix);
        }
      },
      onError: (e) => debugPrint('Location stream error: $e'),
    );
    // startUpdates после подписки: иначе события, пришедшие до listen,
    // терялись, а гонка cancel/start на стороне Kotlin могла полностью
    // остановить обновления.
    _methodChannel.invokeMethod('startUpdates', {'intervalMs': intervalSeconds * 1000});
    return _controller.stream;
  }

  @override
  Future<void> stopWatching() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _methodChannel.invokeMethod('stopUpdates');
    } on PlatformException {
      // ignore
    }
  }

  LocationFix? _parseFix(Map<String, dynamic> map) {
    final lat = (map['lat'] as num?)?.toDouble();
    final lon = (map['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    final p = GeoPoint(lat: lat, lon: lon);
    if (!p.isValid) return null;
    final ts = map['timestampMs'] as int?;
    final acc = (map['accuracy'] as num?)?.toDouble();
    final provider = map['provider'] as String?;
    return LocationFix(
      point: p,
      timestampUtc: ts != null
          ? DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true)
          : DateTime.now().toUtc(),
      accuracyMeters: acc,
      provider: provider,
    );
  }

  LocationStatus _parseStatus(String? s) => switch (s) {
        'available' => LocationStatus.available,
        'permission_denied' => LocationStatus.permissionDenied,
        'service_disabled' => LocationStatus.serviceDisabled,
        _ => LocationStatus.unknown,
      };
}

/// Заглушка для платформ без геолокации (Linux desktop).
class UnsupportedLocationRepository implements LocationRepository {
  const UnsupportedLocationRepository();

  @override
  Future<LocationStatus> checkStatus() async => LocationStatus.unsupported;

  @override
  Future<LocationStatus> requestPermission() async =>
      LocationStatus.unsupported;

  @override
  Future<LocationFix?> getLastKnown() async => null;

  @override
  Stream<LocationFix> watch({required int intervalSeconds}) =>
      const Stream.empty();

  @override
  Future<void> stopWatching() async {}
}
