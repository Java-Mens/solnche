// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:intl/intl.dart';

final _twoDigits = NumberFormat('00');

/// Формат [d] как ЧЧ:ММ:СС, без знака. [d] нормализуется в [0, 24ч).
String formatHms(Duration d) {
  var s = d.inMilliseconds;
  if (s < 0) s = -s;
  s %= 86400000;
  final h = s ~/ 3600000;
  s -= h * 3600000;
  final m = s ~/ 60000;
  s -= m * 60000;
  final sec = s ~/ 1000;
  return '${_twoDigits.format(h)}:${_twoDigits.format(m)}:${_twoDigits.format(sec)}';
}

/// Формат истинного смещения от UTC: `UTC±ЧЧ:ММ:СС`.
String formatUtcOffset(Duration d) {
  final sign = d.isNegative ? '−' : '+';
  var s = d.inMilliseconds.abs();
  final h = s ~/ 3600000;
  s -= h * 3600000;
  final m = s ~/ 60000;
  s -= m * 60000;
  final sec = s ~/ 1000;
  return 'UTC$sign${_twoDigits.format(h)}:${_twoDigits.format(m)}:${_twoDigits.format(sec)}';
}

/// Формат разницы между двумя LAT: `±ЧЧ:ММ:СС`, нормализованной в [-12ч,+12ч].
String formatDiff(Duration d) {
  var ms = d.inMilliseconds;
  // Нормализация в (-12h, +12h]
  const halfDayMs = 12 * 3600 * 1000;
  const fullDayMs = 24 * 3600 * 1000;
  ms = ((ms % fullDayMs) + fullDayMs) % fullDayMs;
  if (ms > halfDayMs) ms -= fullDayMs;
  final sign = ms < 0 ? '−' : '+';
  final abs = ms.abs();
  final h = abs ~/ 3600000;
  var r = abs - h * 3600000;
  final m = r ~/ 60000;
  r -= m * 60000;
  final sec = r ~/ 1000;
  return '$sign${_twoDigits.format(h)}:${_twoDigits.format(m)}:${_twoDigits.format(sec)}';
}

/// Формат UTC-момента как ЧЧ:ММ (или ЧЧ:ММ:СС при [withSeconds]).
String formatUtcTime(DateTime? utc, {bool withSeconds = false}) {
  if (utc == null) return '—';
  final buf = StringBuffer()
    ..write(_twoDigits.format(utc.hour))
    ..write(':')
    ..write(_twoDigits.format(utc.minute));
  if (withSeconds) {
    buf
      ..write(':')
      ..write(_twoDigits.format(utc.second));
  }
  return buf.toString();
}

const _weekdayShort = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

/// Формат события в местном времени устройства: «вс 12.10, 07:21:39».
///
/// Восход/заход/полдень рассчитываются в UTC; для пользователя из
/// Владивостока восход в 21:20 UTC — это 07:20 следующего дня по месту,
/// поэтому дата в выводе обязательна.
String formatLocalEventTime(DateTime? utc) {
  if (utc == null) return '—';
  final local = utc.toLocal();
  final buf = StringBuffer()
    ..write(_weekdayShort[local.weekday - 1])
    ..write(' ')
    ..write(_twoDigits.format(local.day))
    ..write('.')
    ..write(_twoDigits.format(local.month))
    ..write(', ')
    ..write(_twoDigits.format(local.hour))
    ..write(':')
    ..write(_twoDigits.format(local.minute))
    ..write(':')
    ..write(_twoDigits.format(local.second));
  return buf.toString();
}

/// Дата события в местном времени для подзаголовка: «вс 12.10 · UTC 21:21».
String formatLocalEventSub(DateTime? utc) {
  if (utc == null) return '';
  final local = utc.toLocal();
  final utcText = formatUtcTime(utc);
  return '${_weekdayShort[local.weekday - 1]} '
      '${_twoDigits.format(local.day)}.${_twoDigits.format(local.month)}'
      ' · UTC $utcText';
}

/// Метка часового пояса устройства: «UTC+10», «UTC−03:30».
String formatLocalTzLabel() {
  final offset = DateTime.now().timeZoneOffset;
  final sign = offset.isNegative ? '−' : '+';
  final h = offset.inHours.abs();
  final m = offset.inMinutes.abs() % 60;
  final mm = m == 0 ? '' : ':${_twoDigits.format(m)}';
  return 'UTC$sign$h$mm';
}

/// ЧЧ:ММ:СС момента [utc] в местном времени устройства —
/// для метки «координаты обновлены …».
String formatLocalHms(DateTime utc) {
  final l = utc.toLocal();
  return '${_twoDigits.format(l.hour)}:'
      '${_twoDigits.format(l.minute)}:'
      '${_twoDigits.format(l.second)}';
}
