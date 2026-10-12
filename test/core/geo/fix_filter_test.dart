// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:solntsemer/core/geo/geo_point.dart';
import 'package:solntsemer/data/location/location_repository.dart';

void main() {
  final now = DateTime.utc(2026, 10, 12, 12);

  LocationFix fix(
    double lat,
    double lon, {
    Duration? age,
    double? accuracy,
  }) =>
      LocationFix(
        point: GeoPoint(lat: lat, lon: lon),
        timestampUtc: now.subtract(age ?? Duration.zero),
        accuracyMeters: accuracy,
        provider: 'gps',
      );

  group('FixFilter', () {
    test('первый фикс принимается всегда (точки ещё нет)', () {
      const filter = FixFilter();
      expect(filter.accept(fix(43.1, 131.9, accuracy: 2000), null, now),
          isTrue);
    });

    test('устаревший фикс отбрасывается', () {
      const filter = FixFilter(maxAge: Duration(seconds: 90));
      expect(
        filter.accept(
            fix(43.1, 131.9, age: const Duration(minutes: 10)), null, now),
        isFalse,
      );
    });

    test('фикс из будущего (сдвиг часов GPS) отбрасывается', () {
      const filter = FixFilter();
      expect(
        filter.accept(
            fix(43.1, 131.9, age: const Duration(minutes: -5)), null, now),
        isFalse,
      );
    });

    test('неточный фикс при существующей точке отбрасывается', () {
      const filter = FixFilter(maxAccuracyMeters: 100);
      final current = const GeoPoint(lat: 43.1, lon: 131.9);
      expect(filter.accept(fix(43.1003, 131.9003, accuracy: 2000), current, now),
          isFalse);
    });

    test('дрожание GPS менее порога смещения игнорируется', () {
      const filter = FixFilter(minMoveMeters: 25);
      final current = const GeoPoint(lat: 43.1000, lon: 131.9000);
      // ~11 м — меньше порога 25 м.
      expect(
          filter.accept(
              fix(43.1001, 131.9001, accuracy: 10), current, now),
          isFalse);
    });

    test('реальное перемещение принимается', () {
      const filter = FixFilter(minMoveMeters: 25);
      final current = const GeoPoint(lat: 43.1000, lon: 131.9000);
      // ~0.001° ≈ 78 м на восток.
      expect(
          filter.accept(fix(43.1000, 131.9010, accuracy: 10), current, now),
          isTrue);
    });

    test('distanceMeters: малые расстояния (назначение фильтра)', () {
      final p = const GeoPoint(lat: 43.1155, lon: 131.8855);
      // 0.001° широты ≈ 111 м.
      final dLat = FixFilter.distanceMeters(p, const GeoPoint(lat: 43.1165, lon: 131.8855));
      expect(dLat, inInclusiveRange(100, 125));
      // 0.001° долготы на широте 43° ≈ 81 м (111320·cos(43°)).
      final dLon = FixFilter.distanceMeters(p, const GeoPoint(lat: 43.1155, lon: 131.8865));
      expect(dLon, inInclusiveRange(70, 95));
      // Совпадающие точки.
      expect(FixFilter.distanceMeters(p, p), 0);
    });
  });
}
