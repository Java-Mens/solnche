// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:solntsemer/core/geo/geo_point.dart';

void main() {
  group('GeoPoint.isValid', () {
    test('rejects NaN', () {
      expect(const GeoPoint(lat: double.nan, lon: 0).isValid, isFalse);
    });
    test('rejects out of range latitude', () {
      expect(const GeoPoint(lat: 90.1, lon: 0).isValid, isFalse);
    });
    test('rejects out of range longitude', () {
      expect(const GeoPoint(lat: 0, lon: 180.1).isValid, isFalse);
    });
    test('accepts boundary values', () {
      expect(const GeoPoint(lat: 90, lon: 180).isValid, isTrue);
      expect(const GeoPoint(lat: -90, lon: -180).isValid, isTrue);
    });
  });

  group('GeoPoint.tryParse', () {
    test('basic comma-separated decimal', () {
      final p = GeoPoint.tryParse('55.7558, 37.6173');
      expect(p, isNotNull);
      expect(p!.lat, closeTo(55.7558, 1e-6));
      expect(p.lon, closeTo(37.6173, 1e-6));
    });

    test('whitespace separated', () {
      final p = GeoPoint.tryParse('55.7558 37.6173');
      expect(p, isNotNull);
    });

    test('semicolon separated', () {
      final p = GeoPoint.tryParse('55.7558;37.6173');
      expect(p, isNotNull);
    });

    test('N/S/E/W suffixes', () {
      final p = GeoPoint.tryParse('55.7558N 37.6173E');
      expect(p, isNotNull);
      expect(p!.lat, closeTo(55.7558, 1e-6));
      expect(p.lon, closeTo(37.6173, 1e-6));

      final p2 = GeoPoint.tryParse('33.8688S 151.2093E');
      expect(p2, isNotNull);
      expect(p2!.lat, closeTo(-33.8688, 1e-6));
      expect(p2.lon, closeTo(151.2093, 1e-6));
    });

    test('negative numbers', () {
      final p = GeoPoint.tryParse('-33.8688, -151.2093');
      expect(p, isNotNull);
      expect(p!.lat, closeTo(-33.8688, 1e-6));
      expect(p.lon, closeTo(-151.2093, 1e-6));
    });

    test('invalid input returns null', () {
      expect(GeoPoint.tryParse(''), isNull);
      expect(GeoPoint.tryParse('foo bar'), isNull);
      expect(GeoPoint.tryParse('91, 0'), isNull);
      expect(GeoPoint.tryParse('0, 181'), isNull);
      expect(GeoPoint.tryParse('1 2 3'), isNull);
    });
  });

  group('GeoPoint.lonRadWest', () {
    test('east positive input gives negative (west) radians', () {
      const p = GeoPoint(lat: 0, lon: 37.6173);
      expect(p.lonRadWest, closeTo(-0.6566, 1e-3));
    });
  });
}
