// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:solntsemer/core/geo/geo_point.dart';
import 'package:solntsemer/data/dut1/dut1_source.dart';
import 'package:solntsemer/data/widget/widget_repository.dart';

class _FixedDut1 implements Dut1Source {
  final double v;
  const _FixedDut1(this.v);
  @override
  double getDut1(DateTime utc) => v;
  @override
  bool get isPrecise => true;
  @override
  bool isPreciseFor(DateTime utc) => true;
  @override
  String get description => 'fixed';
}

void main() {
  final now = DateTime.utc(2026, 10, 12, 6, 30);
  const pointA = GeoPoint(lat: 43.1155, lon: 131.8855);
  const pointB = GeoPoint(lat: 55.7558, lon: 37.6173, label: 'Москва');
  const fixed = GeoPoint(lat: -33.8688, lon: 151.2093, label: 'Сидней');

  group('resolveWidgetPoint (ТЗ FR-26)', () {
    test('источник A → точка A', () {
      const config = WidgetConfig(source: WidgetPointSource.pointA);
      expect(
        resolveWidgetPoint(config, pointA: pointA, pointB: pointB),
        pointA,
      );
    });

    test('источник B → точка B', () {
      const config = WidgetConfig(source: WidgetPointSource.pointB);
      expect(
        resolveWidgetPoint(config, pointA: pointA, pointB: pointB),
        pointB,
      );
    });

    test('фиксированная точка не зависит от A/B', () {
      const config =
          WidgetConfig(source: WidgetPointSource.fixed, fixedPoint: fixed);
      expect(
        resolveWidgetPoint(config, pointA: pointA, pointB: pointB),
        fixed,
      );
    });

    test('нет точки — null (FR-27: показываем «точка не выбрана»)', () {
      const config = WidgetConfig(source: WidgetPointSource.pointA);
      expect(resolveWidgetPoint(config, pointA: null, pointB: pointB), isNull);
    });
  });

  group('buildWidgetPayload (ТЗ FR-25/27: данные для нативного виджета)', () {
    test('содержит координаты, DUT1, TAI−UTC и флаги отображения', () {
      const dut1 = _FixedDut1(-0.0342);
      const config = WidgetConfig(
        source: WidgetPointSource.pointB,
        showOffset: true,
        showSun: false,
      );
      final payload = buildWidgetPayload(
        config: config,
        pointA: pointA,
        pointB: pointB,
        dut1Source: dut1,
        nowUtc: now,
      );
      expect(payload['source'], 'b');
      expect(payload['hasPoint'], isTrue);
      expect(payload['lat'], pointB.lat);
      expect(payload['lon'], pointB.lon);
      expect(payload['label'], 'Москва'); // подпись точки сохраняется
      expect(payload['dut1'], closeTo(-0.0342, 1e-9));
      expect(payload['dut1Precise'], isTrue);
      expect(payload['taiUtc'], 37); // последняя високосная секунда
      expect(payload['showOffset'], isTrue);
      expect(payload['showSun'], isFalse);
      expect(payload['pushedAtMs'], now.millisecondsSinceEpoch);
    });

    test('без точки hasPoint=false и координат нет', () {
      const dut1 = _FixedDut1(0);
      const config = WidgetConfig(source: WidgetPointSource.pointA);
      final payload = buildWidgetPayload(
        config: config,
        pointA: null,
        pointB: null,
        dut1Source: dut1,
        nowUtc: now,
      );
      expect(payload['hasPoint'], isFalse);
      expect(payload.containsKey('lat'), isFalse);
      expect(payload['dut1'], isNotNull); // поправки всё равно передаём
    });

    test('фиксированная точка помечается source=fixed (без «устарело»)', () {
      const dut1 = _FixedDut1(0);
      const config =
          WidgetConfig(source: WidgetPointSource.fixed, fixedPoint: fixed);
      final payload = buildWidgetPayload(
        config: config,
        pointA: pointA,
        pointB: null,
        dut1Source: dut1,
        nowUtc: now,
      );
      expect(payload['source'], 'fixed');
      expect(payload['label'], 'Сидней');
    });

    test('подпись по умолчанию для точки без label', () {
      const dut1 = _FixedDut1(0);
      const config = WidgetConfig(source: WidgetPointSource.pointA);
      final payload = buildWidgetPayload(
        config: config,
        pointA: pointA, // label пустой
        pointB: null,
        dut1Source: dut1,
        nowUtc: now,
      );
      expect(payload['label'], 'Точка A');
    });
  });
}
