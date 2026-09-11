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
library;

import 'dart:math' as math;

import 'package:astronomia/sidereal.dart' as sidereal;
import 'package:astronomia/solar.dart' as solar;
import 'package:astronomia/eqtime.dart' as eqtime;
import 'package:astronomia/deltat.dart' as deltat;
import 'package:astronomia/planetposition.dart' show Planet;

import '../../data/dut1/dut1_source.dart';
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

  /// Ближайший (к моменту расчёта) восход в UTC, либо null в полярных случаях.
  final DateTime? nextSunriseUtc;

  /// Ближайший заход в UTC, либо null.
  final DateTime? nextSunsetUtc;

  /// Солнечный полдень текущего дня в UTC.
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

  const SolarCalculator({
    required this.dut1Source,
    this.sunriseMode = SunriseMode.observed,
  });

  /// Высота центра Солнца над горизонтом в момент восхода/захода (рад).
  double get _h0Rad => sunriseMode == SunriseMode.observed
      ? _degToRad(-0.833)
      : 0.0;

  SolarSnapshot compute(GeoPoint point, DateTime nowUtc) {
    final dut1 = dut1Source.getDut1(nowUtc);
    final dut1Precise = dut1Source.isPrecise;

    final jdUtc = dateTimeToJd(nowUtc);
    final jdUt1 = jdUtc + dut1 / 86400.0;

    // GAST в UT1 — это видимое звёздное время в Гринвиче.
    final gastSeconds = sidereal.apparent(jdUt1);
    final gastHours = gastSeconds / 3600.0;

    // Для положения Солнца нужен jde (TT). ΔT = TT − UT1; astronomia
    // предоставляет полиномиальные модели. На точность LAT ошибка ΔT
    // не влияет (влияет только на α_sun и нутацию, и там ошибки << 1 с).
    final yearDecimal = _yearFractional(nowUtc);
    final deltaT = _getDeltaT(yearDecimal, jdUt1);
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

    // Восход/заход/полдень: обходим сутки UTC шагами, уточняя переходы.
    final jdTodayUtc = (jdUtc + 0.5).floorToDouble() - 0.5;
    final eventsToday = _riseSetNoon(jdTodayUtc, point);
    final eventsTomorrow = eventsToday.rise != null &&
            eventsToday.set != null &&
            eventsToday.rise! < jdUtc &&
            eventsToday.set! < jdUtc
        ? _riseSetNoon(jdTodayUtc + 1.0, point)
        : null;

    DateTime? pickFuture(double? jdA, double? jdB) {
      final a = jdA == null ? null : jdToDateTime(jdA);
      final b = jdB == null ? null : jdToDateTime(jdB);
      if (a != null && a.isAfter(nowUtc)) return a;
      if (b != null && b.isAfter(nowUtc)) return b;
      return b ?? a;
    }

    final nextSunrise =
        pickFuture(eventsToday.rise, eventsTomorrow?.rise);
    final nextSunset =
        pickFuture(eventsToday.set, eventsTomorrow?.set);
    final solarNoon =
        eventsToday.noon.isNaN ? null : jdToDateTime(eventsToday.noon);

    // Полярные случаи: если ни восхода, ни захода в течение суток — смотрим
    // высоту Солнца в кульминации.
    final polarDay = eventsToday.rise == null &&
        eventsToday.set == null &&
        !eventsToday.noon.isNaN &&
        _altitudeAt(jdTodayUtc + 0.5, point) > 0;
    final polarNight = eventsToday.rise == null &&
        eventsToday.set == null &&
        !eventsToday.noon.isNaN &&
        _altitudeAt(jdTodayUtc + 0.5, point) <= 0;

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

  /// Высота Солнца над горизонтом (рад) в заданный JD (UT).
  double _altitudeAt(double jd, GeoPoint point) {
    final eq = solar.apparentEquatorial(jd);
    final st = sidereal.apparent(jd) / 86400.0 * 2.0 * math.pi;
    return _eqToAlt(eq.ra, eq.dec, point.latRad, point.lonRadWest, st);
  }

  _RiseSetNoon _riseSetNoon(double jd, GeoPoint point) {
    // Используем собственную реализацию с настраиваемым h0 вместо astronomia.sunrise,
    // т.к. последняя имеет жёстко зашитое h0 = −50′ (наблюдаемый режим).
    return _computeRiseSetNoon(jd, point.latRad, point.lonRadWest, _h0Rad);
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

/// ΔT = TT − UT1 в секундах. Использует astronomia.deltat с переключением
/// между табличной интерполяцией (1620–2010) и полиномом после 2000.
double _getDeltaT(double year, double jde) {
  if (year >= 2000 && year < 2100) {
    return deltat.polyAfter2000(year);
  }
  if (year >= 1620 && year <= 2010) {
    return deltat.interp10A(jde);
  }
  // За пределами поддерживаемого диапазона — полином как запасной вариант.
  return deltat.polyAfter2000(year.clamp(2000, 2099));
}

class _RiseSetNoon {
  final double? rise;
  final double noon;
  final double? set;
  const _RiseSetNoon(this.rise, this.noon, this.set);
}

/// Алгоритм восхода/захода по Мёусу (Ch. 15) + бисекция для уточнения.
/// Шагаем по JD-суткам с шагом 5 минут, уточняем момент пересечения h₀
/// бисекцией до ~1 мс.
_RiseSetNoon _computeRiseSetNoon(
    double jd, double latRad, double lonRadWest, double h0) {
  double altitude(double instant) {
    final eq = solar.apparentEquatorial(instant);
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
