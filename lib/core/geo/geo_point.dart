// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math' as math;

/// Географическая точка в WGS84 (EPSG:4326).
///
/// [lat] — широта в градусах, положительная к северу, [-90, +90].
/// [lon] — долгота в градусах, положительная к востоку, [-180, +180].
class GeoPoint {
  final double lat;
  final double lon;
  final String label;

  const GeoPoint({required this.lat, required this.lon, this.label = ''});

  double get latRad => lat * math.pi / 180;

  /// Долгота в радианах с инверсией знака:
  /// astronomia ожидает положительное значение к западу.
  double get lonRadWest => -lon * math.pi / 180;

  bool get isValid =>
      !lat.isNaN &&
      !lon.isNaN &&
      lat >= -90 &&
      lat <= 90 &&
      lon >= -180 &&
      lon <= 180;

  /// Парсит строку вида "55.7558, 37.6173" / "55.7558 37.6173" / "55.7558;37.6173".
  /// Принимает суффиксы N/S/E/W и отрицательные числа.
  static GeoPoint? tryParse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    // Split on comma, semicolon, or whitespace
    final parts = trimmed
        .split(RegExp(r'[,\s;]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length != 2) return null;

    final lat = _parseAngle(parts[0], isLatitude: true);
    final lon = _parseAngle(parts[1], isLatitude: false);
    if (lat == null || lon == null) return null;
    final p = GeoPoint(lat: lat, lon: lon);
    return p.isValid ? p : null;
  }

  static double? _parseAngle(String s, {required bool isLatitude}) {
    var str = s.toUpperCase().trim();
    double sign = 1.0;
    if (str.startsWith('-')) {
      sign = -1.0;
      str = str.substring(1).trim();
    } else if (str.startsWith('+')) {
      str = str.substring(1).trim();
    }
    if (str.endsWith('N')) {
      str = str.substring(0, str.length - 1).trim();
    } else if (str.endsWith('S')) {
      sign *= -1;
      str = str.substring(0, str.length - 1).trim();
    } else if (str.endsWith('E')) {
      str = str.substring(0, str.length - 1).trim();
    } else if (str.endsWith('W')) {
      sign *= -1;
      str = str.substring(0, str.length - 1).trim();
    }
    final v = double.tryParse(str);
    if (v == null) return null;
    final value = sign * v;
    if (isLatitude && (value < -90 || value > 90)) return null;
    if (!isLatitude && (value < -180 || value > 180)) return null;
    return value;
  }

  String formatLat() {
    final v = lat.abs().toStringAsFixed(4);
    return lat >= 0 ? '$v\u00b0N' : '$v\u00b0S';
  }

  String formatLon() {
    final v = lon.abs().toStringAsFixed(4);
    return lon >= 0 ? '$v\u00b0E' : '$v\u00b0W';
  }

  @override
  String toString() {
    final latStr = lat.toStringAsFixed(4);
    final lonStr = lon.toStringAsFixed(4);
    return '$latStr°, $lonStr°';
  }

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);
}
