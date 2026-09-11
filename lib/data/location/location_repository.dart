// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

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
  final DateTime timestampUtc;
  final double? accuracyMeters;

  const LocationFix({
    required this.point,
    required this.timestampUtc,
    this.accuracyMeters,
  });
}

/// Абстракция источника геолокации.
abstract class LocationRepository {
  Future<LocationStatus> checkStatus();

  Future<LocationStatus> requestPermission();

  Future<LocationFix?> getLastKnown();

  Stream<LocationFix> watch({required int intervalSeconds});

  Future<void> stopWatching();
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
    _methodChannel.invokeMethod('startUpdates', {'intervalMs': intervalSeconds * 1000});
    _sub = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final fix = _parseFix(Map<String, dynamic>.from(event));
          if (fix != null) _controller.add(fix);
        }
      },
      onError: (e) => debugPrint('Location stream error: $e'),
    );
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
    return LocationFix(
      point: p,
      timestampUtc: ts != null
          ? DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true)
          : DateTime.now().toUtc(),
      accuracyMeters: acc,
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
