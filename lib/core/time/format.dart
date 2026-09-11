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
