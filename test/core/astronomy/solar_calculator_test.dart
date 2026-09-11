// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:solntsemer/core/astronomy/solar_calculator.dart';
import 'package:solntsemer/core/geo/geo_point.dart';
import 'package:solntsemer/data/dut1/dut1_source.dart';

GeoPoint greenwich = const GeoPoint(lat: 51.477, lon: 0.0, label: 'Greenwich');
GeoPoint moscow = const GeoPoint(lat: 55.7558, lon: 37.6173, label: 'Москва');
GeoPoint equator = const GeoPoint(lat: 0.0, lon: 0.0, label: 'Equator@GM');
GeoPoint northPole = const GeoPoint(lat: 89.0, lon: 0.0, label: 'NearNP');
GeoPoint southPole = const GeoPoint(lat: -89.0, lon: 0.0, label: 'NearSP');

SolarCalculator make({SunriseMode mode = SunriseMode.observed}) =>
    SolarCalculator(dut1Source: const NoDut1Source(), sunriseMode: mode);

Duration eotAt(DateTime utc) {
  return make().compute(equator, utc).equationOfTime;
}

void main() {
  group('Julian Day conversions', () {
    test('J2000.0 epoch = 2000-01-01 12:00 UTC', () {
      final jd = dateTimeToJd(DateTime.utc(2000, 1, 1, 12));
      expect(jd, closeTo(2451545.0, 1e-9));
    });

    test('round-trip JD ↔ DateTime', () {
      final cases = [
        DateTime.utc(2024, 3, 20, 6, 5, 0),
        DateTime.utc(1999, 8, 11, 12, 0, 0),
        DateTime.utc(2026, 9, 12, 23, 59, 59),
        DateTime.utc(2000, 1, 1, 12, 0, 0),
      ];
      for (final c in cases) {
        final jd = dateTimeToJd(c);
        final back = jdToDateTime(jd);
        expect(
          back.difference(c).inMilliseconds.abs(),
          lessThan(2),
          reason: 'round-trip for $c',
        );
      }
    });
  });

  group('Equation of time', () {
    test('EoT is near zero around April 15 (zero crossing)', () {
      final e = eotAt(DateTime.utc(2024, 4, 15, 12)).inSeconds;
      // The crossing varies year to year; within ~2 min of zero on Apr 15.
      expect(e.abs(), lessThan(120));
    });

    test('EoT is near zero around September 1 (zero crossing)', () {
      final e = eotAt(DateTime.utc(2024, 9, 1, 12)).inSeconds;
      expect(e.abs(), lessThan(120));
    });

    test('EoT near maximum in early November (~+16 min)', () {
      final e = eotAt(DateTime.utc(2024, 11, 3, 12)).inSeconds;
      expect(e, inInclusiveRange(16 * 60 - 60, 16 * 60 + 60));
    });

    test('EoT near minimum in mid-February (~−14 min)', () {
      final e = eotAt(DateTime.utc(2024, 2, 11, 12)).inSeconds;
      expect(e, inInclusiveRange(-14 * 60 - 60, -14 * 60 + 60));
    });
  });

  group('Local apparent solar time', () {
    test('At lon=0, LAT ≈ 12:00 on EoT zero-crossing day at 12:00 UTC', () {
      final snap = make().compute(equator, DateTime.utc(2024, 4, 15, 12));
      expect(snap.lat.inMinutes, inInclusiveRange(11 * 60 + 57, 12 * 60 + 3));
    });

    test('LAT at Moscow: lon=37.6173 ⇒ LMT ~14:30 at 12:00 UTC', () {
      final snap = make().compute(moscow, DateTime.utc(2024, 6, 21, 12));
      // LMT = 12 + 37.6173/15 = 14.508 h = 14h 30m 28s
      // E ≈ -1.5 min in June, so LAT ≈ 14:29
      expect(snap.lat.inMinutes, inInclusiveRange(14 * 60 + 26, 14 * 60 + 33));
    });

    test('UTC offset = LAT − UTC_h, normalized to ±12h', () {
      final snap = make().compute(moscow, DateTime.utc(2024, 6, 21, 12));
      final offsetMin = snap.utcOffset.inMinutes;
      // Expected: LAT - 12h ≈ 14:29 - 12:00 = 2h 29m
      expect(offsetMin, inInclusiveRange(2 * 60 + 25, 2 * 60 + 35));
    });

    test('LAT is in [0, 24h)', () {
      for (var h = 0; h < 24; h++) {
        final snap =
            make().compute(moscow, DateTime.utc(2024, 7, 15, h, 30, 0));
        expect(snap.lat.inMilliseconds, inInclusiveRange(0, 24 * 3600 * 1000 - 1));
      }
    });
  });

  group('Internal consistency', () {
    test('Two EoT paths (GAST-α vs eqtime.e) agree within 2 s', () {
      // The calculator uses GAST+λ/15−α+12 for LAT and eqtime.e for EoT.
      // At lon=0, LAT = UTC_h + EoT ⇒ EoT = LAT − UTC_h.
      // The two paths differ by ~1–2 s because GAST is evaluated at UT1
      // while eqtime.e uses TT (ΔT ≈ 70 s), and the equation of the
      // equinoxes differs slightly between the two epochs. This is within
      // the ±1 s + |DUT1| accuracy spec (ТЗ §12.3).
      for (final dt in [
        DateTime.utc(2024, 3, 20, 12),
        DateTime.utc(2024, 6, 21, 12),
        DateTime.utc(2024, 9, 22, 12),
        DateTime.utc(2024, 12, 21, 12),
        DateTime.utc(2024, 1, 1, 0, 0, 0),
        DateTime.utc(2024, 7, 4, 3, 14, 15),
      ]) {
        final snap = make().compute(equator, dt);
        var derivedEotMs =
            snap.lat.inMilliseconds - _hoursOfDayMs(dt);
        // Normalize to [-12h, +12h] to handle midnight wraparound
        const halfDayMs = 12 * 3600 * 1000;
        const fullDayMs = 24 * 3600 * 1000;
        derivedEotMs = ((derivedEotMs % fullDayMs) + fullDayMs) % fullDayMs;
        if (derivedEotMs > halfDayMs) derivedEotMs -= fullDayMs;
        final reportedEotMs = snap.equationOfTime.inMilliseconds;
        expect(
          (derivedEotMs - reportedEotMs).abs(),
          lessThan(2000),
          reason: 'consistency at $dt',
        );
      }
    });
  });

  group('Sunrise / sunset / solar noon', () {
    test('Equinox at Greenwich: sunrise near 06:00 UTC, sunset near 18:10', () {
      final snap = make().compute(greenwich, DateTime.utc(2024, 3, 20, 12));
      expect(snap.polarDay, isFalse);
      expect(snap.polarNight, isFalse);
      expect(snap.nextSunriseUtc, isNotNull);
      expect(snap.nextSunsetUtc, isNotNull);
      expect(snap.nextSunriseUtc!.hour, inInclusiveRange(5, 7));
      expect(snap.nextSunsetUtc!.hour, inInclusiveRange(17, 19));
    });

    test('Solar noon at Greenwich is near 12:00 UTC (equinox)', () {
      final snap = make().compute(greenwich, DateTime.utc(2024, 3, 20, 0));
      expect(snap.solarNoonUtc, isNotNull);
      expect(snap.solarNoonUtc!.hour, inInclusiveRange(11, 13));
    });

    test('Near north pole in June: polar day', () {
      final snap = make().compute(northPole, DateTime.utc(2024, 6, 21, 12));
      expect(snap.polarDay, isTrue);
      expect(snap.nextSunriseUtc, isNull);
      expect(snap.nextSunsetUtc, isNull);
    });

    test('Near north pole in December: polar night', () {
      final snap = make().compute(northPole, DateTime.utc(2024, 12, 21, 12));
      expect(snap.polarNight, isTrue);
      expect(snap.nextSunriseUtc, isNull);
      expect(snap.nextSunsetUtc, isNull);
    });

    test('Observed mode vs geometric: geometric rise is later in the morning', () {
      // At mid-latitudes, geometric sunrise is a few minutes later than
      // observed (because the Sun's center reaches 0° after its upper limb
      // already reached −0.833°).
      final observed = SolarCalculator(
              dut1Source: const NoDut1Source(),
              sunriseMode: SunriseMode.observed)
          .compute(greenwich, DateTime.utc(2024, 6, 21, 0));
      final geometric = SolarCalculator(
              dut1Source: const NoDut1Source(),
              sunriseMode: SunriseMode.geometric)
          .compute(greenwich, DateTime.utc(2024, 6, 21, 0));
      expect(observed.nextSunriseUtc, isNotNull);
      expect(geometric.nextSunriseUtc, isNotNull);
      expect(
        geometric.nextSunriseUtc!.isAfter(observed.nextSunriseUtc!),
        isTrue,
      );
    });
  });

  group('DUT1 handling', () {
    test('NoDut1Source: dut1Precise=false, dut1=0', () {
      final snap = make().compute(equator, DateTime.utc(2024, 6, 21, 12));
      expect(snap.dut1Precise, isFalse);
      expect(snap.dut1Seconds, 0.0);
    });

    test('TableDut1Source: interpolation works and isPrecise=true', () {
      final table = TableDut1Source([
        (60000.0, 0.05),
        (60500.0, -0.10),
        (61000.0, 0.20),
      ]);
      expect(table.isPrecise, isTrue);
      final mid = table.getDut1(_mjdToDateTime(60250.0));
      // Linear interp at 60250 between 60000/0.05 and 60500/-0.10:
      // t = 250/500 = 0.5; value = 0.05 + 0.5*(-0.15) = -0.025
      expect(mid, closeTo(-0.025, 1e-9));
      expect(table.getDut1(_mjdToDateTime(59000.0)), 0.0); // below range
      expect(table.getDut1(_mjdToDateTime(62000.0)), 0.0); // above range
    });

    test('DUT1 shifts GAST by ~1:1 → LAT shifts by ~DUT1', () {
      // Feed a fake DUT1 = +0.5 s and verify LAT moves by ~0.5 s
      // (GAST sensitivity to UT1 is ~1.0027379, so the effect is ~0.5 s ±tiny).
      final dut1 = _FixedDut1(0.5);
      final noDut1 = const NoDut1Source();
      final snapWith = SolarCalculator(dut1Source: dut1)
          .compute(greenwich, DateTime.utc(2024, 6, 21, 12));
      final snapWithout = SolarCalculator(dut1Source: noDut1)
          .compute(greenwich, DateTime.utc(2024, 6, 21, 12));
      final diffMs =
          snapWith.lat.inMilliseconds - snapWithout.lat.inMilliseconds;
      expect(diffMs, inInclusiveRange(400, 600)); // ~500 ms
    });
  });
}

int _hoursOfDayMs(DateTime dt) =>
    (dt.hour * 3600 + dt.minute * 60 + dt.second) * 1000 +
    dt.millisecond +
    dt.microsecond ~/ 1000;

DateTime _mjdToDateTime(double mjd) {
  final jd = mjd + 2400000.5;
  return jdToDateTime(jd);
}

class _FixedDut1 implements Dut1Source {
  final double seconds;
  const _FixedDut1(this.seconds);
  @override
  double getDut1(DateTime nowUtc) => seconds;
  @override
  bool get isPrecise => true;
  @override
  String get description => 'fixed $seconds s';
}

// ignore: unused_element
double _deg(double d) => d * math.pi / 180;
