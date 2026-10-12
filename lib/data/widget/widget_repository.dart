// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../../core/astronomy/solar_calculator.dart';
import '../../core/geo/geo_point.dart';
import '../dut1/dut1_source.dart';

/// Чью точку показывает виджет рабочего стола (ТЗ FR-26).
enum WidgetPointSource {
  /// Точка A: текущее местоположение (в ручном режиме — последняя выбранная).
  pointA,

  /// Точка B (сравнение).
  pointB,

  /// Фиксированная точка, заданная пользователем.
  fixed,
}

/// Настройки отображения виджета (ТЗ FR-26: выбор элементов).
class WidgetConfig {
  final WidgetPointSource source;
  final GeoPoint? fixedPoint;
  final bool showOffset;
  final bool showSun;

  const WidgetConfig({
    this.source = WidgetPointSource.pointA,
    this.fixedPoint,
    this.showOffset = true,
    this.showSun = true,
  });

  WidgetConfig copyWith({
    WidgetPointSource? source,
    GeoPoint? fixedPoint,
    bool? showOffset,
    bool? showSun,
  }) =>
      WidgetConfig(
        source: source ?? this.source,
        fixedPoint: fixedPoint ?? this.fixedPoint,
        showOffset: showOffset ?? this.showOffset,
        showSun: showSun ?? this.showSun,
      );
}

/// Точка, которую виджет должен показывать по текущим настройкам.
GeoPoint? resolveWidgetPoint(
  WidgetConfig config, {
  GeoPoint? pointA,
  GeoPoint? pointB,
}) {
  switch (config.source) {
    case WidgetPointSource.pointA:
      return pointA;
    case WidgetPointSource.pointB:
      return pointB;
    case WidgetPointSource.fixed:
      return config.fixedPoint;
  }
}

/// Собирает полезную нагрузку для нативного виджета: точку, текущие
/// астрономические поправки (DUT1, TAI−UTC) и настройки отображения.
///
/// Нативная сторона использует это для самостоятельного пересчёта времени
/// раз в минуту (AlarmManager), когда приложение не запущено (ТЗ FR-25/27),
/// поэтому здесь всё, что нужно упрощённому калькулятору.
Map<String, Object?> buildWidgetPayload({
  required WidgetConfig config,
  required GeoPoint? pointA,
  required GeoPoint? pointB,
  required Dut1Source dut1Source,
  required DateTime nowUtc,
}) {
  final point = resolveWidgetPoint(config, pointA: pointA, pointB: pointB);
  final dut1 = dut1Source.getDut1(nowUtc);
  final dut1Precise = dut1Source.isPreciseFor(nowUtc);
  final taiUtc = SolarCalculator.taiMinusUtcFor(nowUtc) ?? 37;
  return {
    'source': switch (config.source) {
      WidgetPointSource.pointA => 'a',
      WidgetPointSource.pointB => 'b',
      WidgetPointSource.fixed => 'fixed',
    },
    'hasPoint': point != null,
    if (point != null) ...{
      'lat': point.lat,
      'lon': point.lon,
      'label': point.label.isEmpty ? _defaultLabel(config.source) : point.label,
    },
    'dut1': dut1,
    'dut1Precise': dut1Precise,
    'taiUtc': taiUtc,
    'showOffset': config.showOffset,
    'showSun': config.showSun,
    'pushedAtMs': nowUtc.millisecondsSinceEpoch,
  };
}

String _defaultLabel(WidgetPointSource source) => switch (source) {
      WidgetPointSource.pointA => 'Точка A',
      WidgetPointSource.pointB => 'Точка B',
      WidgetPointSource.fixed => 'Точка',
    };

/// Канал связи с нативным виджетом Android.
abstract class WidgetChannel {
  bool get supported;

  /// Проталкивает конфигурацию и данные точки в нативную часть
  /// и немедленно обновляет все экземпляры виджета.
  Future<void> push(Map<String, Object?> payload);
}

class AndroidWidgetChannel implements WidgetChannel {
  static const _channel = MethodChannel('dev.atom42.solntsemer/widget');

  @override
  bool get supported => Platform.isAndroid;

  @override
  Future<void> push(Map<String, Object?> payload) async {
    try {
      await _channel.invokeMethod('update', payload);
    } on PlatformException {
      // виджет не добавлен — не критично
    }
  }
}

/// Заглушка для платформ без виджета (GNU/Linux, ТЗ §17.2).
class UnsupportedWidgetChannel implements WidgetChannel {
  @override
  bool get supported => false;

  @override
  Future<void> push(Map<String, Object?> payload) async {}
}
