// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:solntsemer/core/astronomy/solar_calculator.dart' show jdToDateTime;
import 'package:solntsemer/data/dut1/dut1_source.dart';
import 'package:solntsemer/data/dut1/dut1_table.dart';

/// DateTime по MJD.
DateTime _mjd(int mjd) => jdToDateTime(mjd + 2400000.5);

void main() {
  group('Таблица DUT1 (данные IERS)', () {
    final src = TableDut1Source(kDut1Entries);

    test('таблица не пуста и отсортирована по MJD', () {
      expect(kDut1Entries, isNotEmpty);
      for (var i = 1; i < kDut1Entries.length; i++) {
        expect(kDut1Entries[i].$1,
            greaterThanOrEqualTo(kDut1Entries[i - 1].$1));
      }
    });

    test('все значения в допустимом диапазоне |DUT1| ≤ 0.9', () {
      for (final e in kDut1Entries) {
        expect(e.$2.abs(), lessThanOrEqualTo(0.9),
            reason: 'MJD ${e.$1}: ${e.$2}');
      }
    });

    test('isPreciseFor: внутри покрытия — true, вне — false', () {
      // Покрытие: 2015-01-01 .. 2027-10-04 (MJD 57023..61682).
      expect(src.isPreciseFor(_mjd(61325)), isTrue); // 2026-10-12
      expect(src.isPreciseFor(_mjd(57500)), isTrue); // 2016-09-17
      expect(src.isPreciseFor(_mjd(56000)), isFalse); // 2012-12-28 (до таблицы)
      expect(src.isPreciseFor(_mjd(62000)), isFalse); // 2028-11-11 (после)
    });

    test('DUT1 на 2026-10-12 ≈ −0.034 с', () {
      // Значение из finals2000A.daily (IERS Bulletin A).
      final v = src.getDut1(DateTime.utc(2026, 10, 12, 12));
      expect(v, closeTo(-0.0341851, 0.01));
    });

    test('високосная секунда 2017-01-01: скачок ровно на +1 с', () {
      // 2016-12-31: −0.408; 2017-01-01 (после вставки секунды): +0.591.
      final before = src.getDut1(DateTime.utc(2016, 12, 31, 12));
      final after = src.getDut1(DateTime.utc(2017, 1, 1, 12));
      expect(before, closeTo(-0.4077601, 0.01));
      expect(after, closeTo(0.5912821, 0.01));
      expect(after - before, closeTo(1.0, 0.02));
    });

    test('високосная секунда 2015-07-01: скачок ровно на +1 с', () {
      final before = src.getDut1(DateTime.utc(2015, 6, 30, 12));
      final after = src.getDut1(DateTime.utc(2015, 7, 1, 12));
      expect(before, closeTo(-0.6760316, 0.01));
      expect(after, closeTo(0.3233682, 0.01));
      expect(after - before, closeTo(1.0, 0.02));
    });

    test('интерполяция плавная: соседние дни различаются < 3 мс', () {
      // Проверяем пару десятков дат в 2026 году: суточное изменение DUT1
      // не превышает ~1.5 мс/сутки (кроме високосных скачков).
      for (var mjd = 61041; mjd <= 61100; mjd++) {
        final a = src.getDut1(_mjd(mjd));
        final b = src.getDut1(_mjd(mjd + 1));
        expect((b - a).abs(), lessThan(0.003),
            reason: 'MJD $mjd → ${mjd + 1}: $a → $b');
      }
    });
  });

  group('Таблица високосных секунд', () {
    test('отсортирована, начинается с 1972-01-01 = 10 с', () {
      expect(kLeapSeconds.first.$1, 41317.0); // 1972-01-01
      expect(kLeapSeconds.first.$2, 10);
      for (var i = 1; i < kLeapSeconds.length; i++) {
        expect(kLeapSeconds[i].$1, greaterThan(kLeapSeconds[i - 1].$1));
      }
    });

    test('последняя високосная секунда: 2017-01-01, TAI−UTC = 37', () {
      expect(kLeapSeconds.last.$1, 57754.0); // 2017-01-01
      expect(kLeapSeconds.last.$2, 37);
    });

    test('28 исторических високосных секунд 1972–2016', () {
      expect(kLeapSeconds.length, 28);
    });
  });
}
