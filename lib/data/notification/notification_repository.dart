// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';

import 'package:flutter/services.dart';

import '../../core/astronomy/solar_calculator.dart';
import '../../core/geo/geo_point.dart';
import '../../core/time/format.dart';

/// Какая точка отображается в постоянном уведомлении (ТЗ FR-22):
/// текущее местоположение — это точка A в режиме слежения,
/// вручную выбранная точка — точка A/B в ручном режиме.
enum NotificationPoint { pointA, pointB }

/// Заголовок уведомления: «Истинное время: ЧЧ:ММ:СС» (ТЗ FR-20).
String notificationTitle(SolarSnapshot snap) =>
    'Истинное время: ${formatHms(snap.lat)}';

/// Текст уведомления: смещение и точка (ТЗ FR-20).
String notificationText(SolarSnapshot snap, GeoPoint? point) {
  final pointPart = point == null
      ? 'точка не выбрана'
      : '${point.label.isEmpty ? 'Точка' : point.label}: '
          '${point.toString()}';
  return 'Смещение: ${formatUtcOffset(snap.utcOffset)} · $pointPart';
}

/// Канал связи с нативной частью постоянного уведомления (FR-20..FR-23).
abstract class NotificationChannel {
  /// Поддерживается ли платформой (Android; на Linux уведомлений нет, §17.2).
  bool get supported;

  /// Выдано ли разрешение `POST_NOTIFICATIONS` (Android 13+, ТЗ FR-23).
  Future<bool> isPermitted();

  /// Запрашивает разрешение; возвращает `true`, если оно выдано.
  Future<bool> requestPermission();

  /// Запускает foreground service с постоянным уведомлением.
  Future<void> start({
    required String title,
    required String text,
    double? lat,
    double? lon,
    String? label,
  });

  /// Обновляет текст уведомления (вызывается каждую секунду из Dart).
  Future<void> update({
    required String title,
    required String text,
    double? lat,
    double? lon,
    String? label,
  });

  /// Останавливает службу и убирает уведомление.
  Future<void> stop();
}

/// Реализация для Android: MethodChannel → NotificationPlugin.kt →
/// SolarTimeService (foreground service).
class AndroidNotificationChannel implements NotificationChannel {
  static const _channel = MethodChannel('dev.atom42.solntsemer/notification');

  @override
  bool get supported => Platform.isAndroid;

  @override
  Future<bool> isPermitted() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('isPermitted') ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> start({
    required String title,
    required String text,
    double? lat,
    double? lon,
    String? label,
  }) async {
    try {
      await _channel.invokeMethod('start', {
        'title': title,
        'text': text,
        'lat': ?lat,
        'lon': ?lon,
        'label': ?label,
      });
    } on PlatformException {
      // служба недоступна — приложение продолжает работать (ТЗ §20.8)
    }
  }

  @override
  Future<void> update({
    required String title,
    required String text,
    double? lat,
    double? lon,
    String? label,
  }) async {
    try {
      await _channel.invokeMethod('update', {
        'title': title,
        'text': text,
        'lat': ?lat,
        'lon': ?lon,
        'label': ?label,
      });
    } on PlatformException {
      // молча: приложение работает и без уведомления (ТЗ FR-23)
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } on PlatformException {
      // игнорируем
    }
  }
}

/// Заглушка для платформ без уведомлений (GNU/Linux, ТЗ §17.2).
class UnsupportedNotificationChannel implements NotificationChannel {
  @override
  bool get supported => false;

  @override
  Future<bool> isPermitted() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> start({
    required String title,
    required String text,
    double? lat,
    double? lon,
    String? label,
  }) async {}

  @override
  Future<void> update({
    required String title,
    required String text,
    double? lat,
    double? lon,
    String? label,
  }) async {}

  @override
  Future<void> stop() async {}
}
