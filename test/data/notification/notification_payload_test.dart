// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:solntsemer/core/astronomy/solar_calculator.dart';
import 'package:solntsemer/core/geo/geo_point.dart';
import 'package:solntsemer/data/notification/notification_repository.dart';

SolarSnapshot _snap({
  required Duration lat,
  required Duration offset,
  bool precise = true,
}) =>
    SolarSnapshot(
      lat: lat,
      utcOffset: offset,
      equationOfTime: Duration.zero,
      dut1Seconds: -0.0342,
      dut1Precise: precise,
      nextSunriseUtc: null,
      nextSunsetUtc: null,
      solarNoonUtc: null,
      polarDay: false,
      polarNight: false,
    );

void main() {
  group('notificationTitle / notificationText (ТЗ FR-20)', () {
    test('формат заголовка «Истинное время: ЧЧ:ММ:СС»', () {
      final snap = _snap(
        lat: const Duration(hours: 13, minutes: 45, seconds: 26),
        offset: const Duration(hours: 2, minutes: 13, seconds: 45),
      );
      expect(notificationTitle(snap), 'Истинное время: 13:45:26');
    });

    test('текст: смещение и координаты точки с подписью', () {
      final snap = _snap(
        lat: const Duration(hours: 13, minutes: 45, seconds: 26),
        offset: const Duration(hours: 2, minutes: 13, seconds: 45),
      );
      const point = GeoPoint(lat: 55.7558, lon: 37.6173, label: 'Москва');
      final text = notificationText(snap, point);
      expect(text, startsWith('Смещение: UTC+02:13:45'));
      expect(text, contains('Москва: 55.7558°, 37.6173°'));
    });

    test('текст для точки без подписи — «Точка»', () {
      final snap = _snap(
        lat: const Duration(hours: 9),
        offset: const Duration(hours: 9),
      );
      const point = GeoPoint(lat: 43.1155, lon: 131.8855);
      expect(notificationText(snap, point), contains('Точка: 43.1155'));
    });

    test('текст без точки — понятное сообщение (ТЗ FR-22)', () {
      final snap = _snap(
        lat: const Duration(hours: 9),
        offset: const Duration(hours: 9),
      );
      expect(notificationText(snap, null), contains('точка не выбрана'));
    });

    test('отрицательное смещение — знак минус', () {
      final snap = _snap(
        lat: const Duration(hours: 23),
        offset: const Duration(hours: -1, minutes: -30),
      );
      expect(
        notificationText(snap, const GeoPoint(lat: 0, lon: -30)),
        contains('UTC−01:30:00'),
      );
    });
  });

  group('NotificationPoint (ТЗ FR-22)', () {
    test('два источника: текущая точка и точка сравнения', () {
      expect(NotificationPoint.values, hasLength(2));
      expect(NotificationPoint.pointA.name, 'pointA');
      expect(NotificationPoint.pointB.name, 'pointB');
    });
  });
}
