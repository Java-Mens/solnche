// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

/// Расчёт истинного местного солнечного времени (LAT), уравнения времени,
/// смещения от UTC, восхода/захода/полдня для заданной точки.
///
/// Реализация соответствует ТЗ §12. Формула (§12.1):
///
///     LAT = (GAST + λ/15 − α_sun_apparent + 12h) mod 24h
///
/// Альтернативно — через уравнение времени (§28 Мёус):
///
///     LAT = LMT + E,   LMT = UTC + λ/15
///
/// Поправка DUT1 применяется к аргументу [sidereal.apparent] (зависит от
/// вращения Земли, 1:1). Для α_sun и нутации сдвиг jde на DUT1
/// пренебрежимо мал (≤0.9 с → ошибка α ≤ 0.04″ → ошибка LAT ≤ 0.003 с).
///
/// Восход/заход/полдень возвращаются как БЛИЖАЙШИЕ события от текущего
/// момента (а не события «текущих UTC-суток», как раньше): восход на
/// Дальнем Востоке может происходить в 21:xx UTC предыдущих суток, и
/// полуночная граница UTC-дня не должна влиять на выбор события.
library;

import 'dart:math' as math;

import 'package:astronomia/sidereal.dart' as sidereal;
import 'package:astronomia/solar.dart' as solar;
import 'package:astronomia/eqtime.dart' as eqtime;
import 'package:astronomia/deltat.dart' as deltat;
import 'package:astronomia/planetposition.dart' show Planet;

import '../../data/dut1/dut1_source.dart';
import '../../data/dut1/dut1_table.dart' show kLeapSeconds;
import '../geo/geo_point.dart';

/// Режим расчёта восхода/захода (FR-18).
enum SunriseMode {
  /// Наблюдаемый: верхний край диска со стандартной рефракцией,
  /// высота центра Солнца h₀ = −0.833°.
  observed,

  /// Геометрический/астрономический: центр диска на геометрическом горизонте,
  /// h₀ = 0°.
  geometric,
}

class SolarSnapshot {
  /// Истинное местное солнечное время в виде продолжительности от полуночи.
  final Duration lat;

  /// Истинное смещение LAT − UTC в текущий момент.
  final Duration utcOffset;

  /// Уравнение времени E = LAT − LMT.
  final Duration equationOfTime;

  /// Использованное значение DUT1 (секунды).
  final double dut1Seconds;

  /// `true`, если DUT1 получен из актуального источника.
  final bool dut1Precise;

  /// Ближайший восход в UTC (не раньше момента расчёта), либо null в
  /// полярных случаях.
  final DateTime? nextSunriseUtc;

  /// Ближайший заход в UTC, либо null.
  final DateTime? nextSunsetUtc;

  /// Ближайший солнечный полдень в UTC (не раньше момента расчёта).
  final DateTime? solarNoonUtc;

  /// Полярный день (Солнце не заходит).
  final bool polarDay;

  /// Полярная ночь (Солнце не восходит).
  final bool polarNight;

  const SolarSnapshot({
    required this.lat,
    required this.utcOffset,
    required this.equationOfTime,
    required this.dut1Seconds,
    required this.dut1Precise,
    required this.nextSunriseUtc,
    required this.nextSunsetUtc,
    required this.solarNoonUtc,
    required this.polarDay,
    required this.polarNight,
  });
}

class SolarCalculator {
  final Dut1Source dut1Source;
  final SunriseMode sunriseMode;

  /// Кэш расчётов восход/заход/полдень по (точка, режим, JD-сутки).
  /// Расчёт занимает ~300–800 вычислений положения Солнца, а перерисовка
  /// происходит каждую секунду — кэширование обязательно.
  final Map<String, _RiseSetNoon> _riseSetCache = {};

  static const _maxCacheEntries = 32;

  SolarCalculator({
    required this.dut1Source,
    this.sunriseMode = SunriseMode.observed,
  });

  /// Высота центра Солнца над горизонтом в момент восхода/захода (рад).
  double get _h0Rad => sunriseMode == SunriseMode.observed
      ? _degToRad(-0.833)
      : 0.0;

  SolarSnapshot compute(GeoPoint point, DateTime nowUtc) {
    final dut1 = dut1Source.getDut1(nowUtc);
    final dut1Precise = dut1Source.isPreciseFor(nowUtc);

    final jdUtc = dateTimeToJd(nowUtc);
    final jdUt1 = jdUtc + dut1 / 86400.0;

    // GAST в UT1 — это видимое звёздное время в Гринвиче.
    final gastSeconds = sidereal.apparent(jdUt1);
    final gastHours = gastSeconds / 3600.0;

    final yearDecimal = _yearFractional(nowUtc);
    final deltaT = _getDeltaT(yearDecimal, jdUt1, dut1);
    final jde = jdUt1 + deltaT / 86400.0;

    final sun = solar.apparentEquatorial(jde);
    final alphaApparentHours = sun.ra * 12.0 / math.pi;

    var latHours = gastHours + point.lon / 15.0 - alphaApparentHours + 12.0;
    latHours = latHours - 24.0 * (latHours / 24.0).floor();

    final utcHoursOfDay = nowUtc.hour +
        nowUtc.minute / 60.0 +
        (nowUtc.second + nowUtc.microsecond / 1e6) / 3600.0;
    final utcOffsetHours = _normalizeTo12(latHours - utcHoursOfDay);

    // Уравнение времени через VSOP87 (высокая точность, §28 Мёус).
    // eSmart (упрощённое) используется только если Earth недоступен;
    // для основной траектории всегда e().
    final eotHours = _equationOfTimeHours(jde);

    // Восход/заход/полдень: всегда считаем текущие и следующие UTC-сутки
    // (с кэшем), затем выбираем ближайшие события от текущего момента.
    final jdTodayUtc = (jdUtc + 0.5).floorToDouble() - 0.5;
    final eventsToday = _riseSetNoonCached(jdTodayUtc, point, deltaT);
    final eventsTomorrow = _riseSetNoonCached(jdTodayUtc + 1.0, point, deltaT);

    final nextSunrise =
        _pickNext(eventsToday.rise, eventsTomorrow.rise, nowUtc);
    final nextSunset = _pickNext(eventsToday.set, eventsTomorrow.set, nowUtc);
    final solarNoon = eventsToday.noon.isNaN
        ? _pickNext(null, eventsTomorrow.noon.isNaN ? null : eventsTomorrow.noon, nowUtc)
        : _pickNext(eventsToday.noon, eventsTomorrow.noon, nowUtc);

    // Полярные случаи: ни восхода, ни захода в ближайшие ~48 часов.
    // Ориентируемся на текущее положение Солнца над горизонтом.
    final sunUpNow = _altitudeAtJd(jdUtc, point, deltaT) > 0;
    final polarDay = nextSunrise == null && nextSunset == null && sunUpNow;
    final polarNight = nextSunrise == null && nextSunset == null && !sunUpNow;

    return SolarSnapshot(
      lat: _hoursToDuration(latHours),
      utcOffset: _hoursToDuration(utcOffsetHours),
      equationOfTime: _hoursToDuration(eotHours),
      dut1Seconds: dut1,
      dut1Precise: dut1Precise,
      nextSunriseUtc: nextSunrise,
      nextSunsetUtc: nextSunset,
      solarNoonUtc: solarNoon,
      polarDay: polarDay,
      polarNight: polarNight,
    );
  }

  /// Выбирает ближайшее событие из «сегодня»/«завтра» (не раньше [nowUtc]).
  /// Если оба события в прошлом или null — возвращает последнее известное.
  DateTime? _pickNext(double? jdA, double? jdB, DateTime nowUtc) {
    final a = jdA == null ? null : jdToDateTime(jdA);
    if (a != null && a.isAfter(nowUtc)) return a;
    final b = jdB == null ? null : jdToDateTime(jdB);
    if (b != null && b.isAfter(nowUtc)) return b;
    return b ?? a;
  }

  double _equationOfTimeHours(double jde) {
    try {
      final earth = Planet(2);
      final eotRadians = eqtime.e(jde, earth);
      return eotRadians * 12.0 / math.pi;
    } catch (_) {
      // Fallback на упрощённую формулу (точность ~±30 с, но без риска крэша).
      final eotRadians = eqtime.eSmart(jde);
      return eotRadians * 12.0 / math.pi;
    }
  }

  _RiseSetNoon _riseSetNoonCached(
      double jdDay, GeoPoint point, double deltaT) {
    final key = '${point.lat.toStringAsFixed(6)},'
        '${point.lon.toStringAsFixed(6)},'
        '${_h0Rad.toStringAsFixed(6)},'
        '${jdDay.toStringAsFixed(1)}';
    final cached = _riseSetCache[key];
    if (cached != null) return cached;
    if (_riseSetCache.length >= _maxCacheEntries) {
      _riseSetCache.clear();
    }
    return _riseSetCache[key] =
        _computeRiseSetNoon(jdDay, point.latRad, point.lonRadWest, _h0Rad, deltaT);
  }

  /// Высота Солнца над горизонтом (рад) в заданный JD (UT).
  double _altitudeAtJd(double jd, GeoPoint point, double deltaT) {
    final eq = solar.apparentEquatorial(jd + deltaT / 86400.0);
    final st = sidereal.apparent(jd) / 86400.0 * 2.0 * math.pi;
    return _eqToAlt(eq.ra, eq.dec, point.latRad, point.lonRadWest, st);
  }

  /// ΔT = TT − UT1 (секунды) для момента [nowUtc] при заданном DUT1.
  ///
  /// Публичный статический метод — для тестов и внешнего использования.
  static double deltaTFor(DateTime nowUtc, double dut1) {
    return _getDeltaT(
        _yearFractional(nowUtc), dateTimeToJd(nowUtc) + dut1 / 86400.0, dut1);
  }
}

/// Перевод DateTime (UTC) в Julian Day.
double dateTimeToJd(DateTime utc) {
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

/// Перевод Julian Day в DateTime (UTC).
DateTime jdToDateTime(double jd) {
  final z = (jd + 0.5).floor();
  final f = jd + 0.5 - z;
  int a;
  if (z < 2299161) {
    a = z;
  } else {
    final alpha = ((z - 1867216.25) / 36524.25).floor();
    a = z + 1 + alpha - alpha ~/ 4;
  }
  final b = a + 1524;
  final c = ((b - 122.1) / 365.25).floor();
  final d = (365.25 * c).floor();
  final e = ((b - d) / 30.6001).floor();
  final day = b - d - (30.6001 * e).floor();
  final month = e < 14 ? e - 1 : e - 13;
  final year = month > 2 ? c - 4716 : c - 4715;
  final dayFrac = day + f;
  final dayInt = dayFrac.floor();
  var remaining = (dayFrac - dayInt) * 86400.0;
  final hour = remaining ~/ 3600;
  remaining -= hour * 3600;
  final minute = remaining ~/ 60;
  remaining -= minute * 60;
  final second = remaining.floor();
  final micro = ((remaining - second) * 1e6).round();
  return DateTime.utc(year, month, dayInt, hour, minute, second, 0, micro);
}

double _degToRad(double deg) => deg * math.pi / 180.0;

double _normalizeTo12(double hours) {
  var h = hours;
  while (h > 12.0) {
    h -= 24.0;
  }
  while (h <= -12.0) {
    h += 24.0;
  }
  return h;
}

Duration _hoursToDuration(double hours) {
  final ms = (hours * 3600 * 1000).round();
  return Duration(milliseconds: ms);
}

double _yearFractional(DateTime utc) {
  final start = DateTime.utc(utc.year, 1, 1);
  final end = DateTime.utc(utc.year + 1, 1, 1);
  final frac = utc.difference(start).inMicroseconds /
      end.difference(start).inMicroseconds;
  return utc.year + frac;
}

/// ΔT = TT − UT1 в секундах.
///
/// С 1972-01-01 вычисляется точно из определения шкал:
///
///     TT = TAI + 32.184 с,   TAI = UTC + (TAI − UTC),   UT1 = UTC + DUT1
///     ΔT = 32.184 + (TAI − UTC) − DUT1
///
/// где (TAI − UTC) — целое число високосных секунд из [kLeapSeconds]
/// (история IERS Bulletin C), а DUT1 — текущая поправка источника.
/// До 1972 года — табличная интерполяция astronomia (Meeus, гл. 10).
double _getDeltaT(double year, double jdUt1, double dut1) {
  final taiMinusUtc = _taiMinusUtcFor(jdUt1);
  if (taiMinusUtc != null) {
    return 32.184 + taiMinusUtc - dut1;
  }
  if (year >= 1620 && year <= 2010) {
    return deltat.interp10A(jdUt1);
  }
  return deltat.polyAfter2000(year.clamp(2005, 2099).toDouble());
}

/// TAI − UTC (секунды) для заданного JD(UT) по таблице високосных секунд.
/// Возвращает null для дат раньше 1972-01-01.
double? _taiMinusUtcFor(double jdUt) {
  if (kLeapSeconds.isEmpty) return null;
  final mjd = jdUt - 2400000.5;
  if (mjd < kLeapSeconds.first.$1) return null;
  var lo = 0, hi = kLeapSeconds.length - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) ~/ 2;
    if (kLeapSeconds[mid].$1 <= mjd) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return kLeapSeconds[lo].$2.toDouble();
}

class _RiseSetNoon {
  final double? rise;
  final double noon;
  final double? set;
  const _RiseSetNoon(this.rise, this.noon, this.set);
}

/// Алгоритм восхода/захода по Мёусу (Ch. 15) + бисекция для уточнения.
/// Шагаем по JD-суткам с шагом 5 минут, уточняем момент пересечения h₀
/// бисекцией до ~1 мс. [deltaT] используется для перевода JD(UT) в JDE
/// при вычислении положения Солнца (GAST остаётся функцией UT).
_RiseSetNoon _computeRiseSetNoon(
    double jd, double latRad, double lonRadWest, double h0, double deltaT) {
  double altitude(double instant) {
    final eq = solar.apparentEquatorial(instant + deltaT / 86400.0);
    final st = sidereal.apparent(instant) / 86400.0 * 2.0 * math.pi;
    return _eqToAlt(eq.ra, eq.dec, latRad, lonRadWest, st);
  }

  const step = 5.0 / 1440.0;
  double? rise;
  double? set;
  var highestAt = jd;
  var highestAlt = altitude(jd);
  var prevJd = jd;
  var prev = highestAlt - h0;

  for (var t = jd + step; t <= jd + 1.0 + 1e-12; t += step) {
    final cur = altitude(t);
    final d = cur - h0;
    if (cur > highestAlt) {
      highestAlt = cur;
      highestAt = t;
    }
    if (prev <= 0 && d > 0) {
      rise ??= _bisect(prevJd, t, altitude, h0, rising: true);
    } else if (prev >= 0 && d < 0) {
      set ??= _bisect(prevJd, t, altitude, h0, rising: false);
    }
    prevJd = t;
    prev = d;
  }

  // Уточнение кульминации тернарным поиском.
  var left = highestAt - step;
  var right = highestAt + step;
  for (var i = 0; i < 40; i++) {
    final third = (right - left) / 3.0;
    final a = left + third;
    final b = right - third;
    if (altitude(a) < altitude(b)) {
      left = a;
    } else {
      right = b;
    }
  }
  final noon = (left + right) / 2.0;
  return _RiseSetNoon(rise, noon, set);
}

double _bisect(double left, double right, double Function(double) altitude,
    double h0,
    {required bool rising}) {
  final belowAtLeft = altitude(left) < h0;
  for (var i = 0; i < 50; i++) {
    final mid = (left + right) / 2.0;
    final belowAtMid = altitude(mid) < h0;
    if (belowAtMid == belowAtLeft) {
      left = mid;
    } else {
      right = mid;
    }
  }
  return (left + right) / 2.0;
}

/// Высота небесного тела над горизонтом (рад) по экваториальным координатам.
/// [lonRadWest] — долгота наблюдателя, положительная к западу (как в astronomia).
double _eqToAlt(
    double ra, double dec, double lat, double lonRadWest, double gast) {
  // Local sidereal time = GAST − longitude (positive west)
  var lst = gast - lonRadWest;
  lst = lst % (2 * math.pi);
  final h = lst - ra; // hour angle
  final sLat = math.sin(lat), cLat = math.cos(lat);
  final sDec = math.sin(dec), cDec = math.cos(dec);
  final sAlt = sLat * sDec + cLat * cDec * math.cos(h);
  return math.asin(sAlt.clamp(-1.0, 1.0));
}
