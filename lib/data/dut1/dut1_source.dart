// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

/// Источник поправки DUT1 = UT1 − UTC (секунды).
///
/// ТЗ §12.5 допускает встроенную таблицу или использование UTC как UT1
/// с индикацией пониженной точности.
abstract class Dut1Source {
  /// Значение DUT1 (секунды) для данного момента [nowUtc].
  double getDut1(DateTime nowUtc);

  /// `true`, если значение получено из актуального источника (таблица IERS,
  /// встроенная таблица); `false`, если используется приближение UTC ≈ UT1.
  bool get isPrecise;

  /// Человекочитаемое описание источника (для экрана настроек / о приложении).
  String get description;
}

/// Источник «нет данных DUT1»: возвращает 0, точность понижена.
class NoDut1Source implements Dut1Source {
  const NoDut1Source();

  @override
  double getDut1(DateTime nowUtc) => 0.0;

  @override
  bool get isPrecise => false;

  @override
  String get description => 'UTC ≈ UT1 (поправка недоступна, точность ±0.9 с)';
}

/// Встроенная таблица DUT1 с линейной интерполяцией.
///
/// Данные генерируются из IERS Bulletin A (см. tool/fetch_dut1.dart) и
/// хранятся в виде пар `(mjd, dut1)`, где mjd — Modified Julian Day.
/// Если момент выходит за границы таблицы — возвращается 0 и [isPrecise]=false.
class TableDut1Source implements Dut1Source {
  /// `[(mjd, dut1), ...]`, отсортировано по mjd.
  final List<(double, double)> entries;

  const TableDut1Source(this.entries);

  @override
  bool get isPrecise => entries.isNotEmpty;

  @override
  String get description => entries.isEmpty
      ? 'Встроенная таблица DUT1 (пуста)'
      : 'Встроенная таблица DUT1 (MJD ${entries.first.$1.toStringAsFixed(1)}–${entries.last.$1.toStringAsFixed(1)})';

  @override
  double getDut1(DateTime nowUtc) {
    if (entries.isEmpty) return 0.0;
    final mjd = _dateTimeToMjd(nowUtc);
    if (mjd < entries.first.$1 || mjd > entries.last.$1) return 0.0;
    // Бинарный поиск интервала
    var lo = 0, hi = entries.length - 1;
    while (lo + 1 < hi) {
      final mid = (lo + hi) ~/ 2;
      if (entries[mid].$1 <= mjd) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final a = entries[lo];
    final b = entries[hi];
    if (a.$1 == b.$1) return a.$2;
    final t = (mjd - a.$1) / (b.$1 - a.$1);
    return a.$2 + t * (b.$2 - a.$2);
  }
}

double _dateTimeToMjd(DateTime utc) {
  // MJD = JD - 2400000.5
  final jd = _dateTimeToJd(utc);
  return jd - 2400000.5;
}

double _dateTimeToJd(DateTime utc) {
  var y = utc.year;
  var m = utc.month;
  double d = utc.day +
      utc.hour / 24.0 +
      utc.minute / 1440.0 +
      (utc.second + utc.microsecond / 1e6) / 86400.0;
  if (m <= 2) {
    y -= 1;
    m += 12;
  }
  final a = y ~/ 100;
  final b = 2 - a + a ~/ 4;
  return (365.25 * (y + 4716)).floor() +
      (30.6001 * (m + 1)).floor() +
      d +
      b -
      1524.5;
}
