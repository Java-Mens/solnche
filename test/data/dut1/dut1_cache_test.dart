// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:solntsemer/data/dut1/dut1_cache.dart';
import 'package:solntsemer/data/dut1/dut1_source.dart';

void main() {
  group('encode/decode кэша', () {
    test('roundtrip', () {
      final entries = <(double, double)>[
        (61320.0, -0.0342),
        (61325.0, -0.0343),
      ];
      final raw = encodeDut1Cache(entries);
      expect(decodeDut1Cache(raw), entries);
    });

    test('пустая строка → null', () {
      expect(decodeDut1Cache(''), isNull);
    });

    test('мусор → null', () {
      expect(decodeDut1Cache('abc'), isNull);
      expect(decodeDut1Cache('61320.0'), isNull); // нет двоеточия
      expect(decodeDut1Cache('61320.0:не-число'), isNull);
      expect(decodeDut1Cache('NaN:-0.03'), isNull);
      expect(decodeDut1Cache('Infinity:-0.03'), isNull);
    });

    test('нарушена сортировка → null', () {
      expect(
        decodeDut1Cache('61325.0:-0.03;61320.0:-0.02'),
        isNull,
      );
    });
  });

  group('mergeDut1', () {
    test('пустая сеть → встроенная таблица как есть', () {
      final builtIn = <(double, double)>[(10.0, 1.0), (20.0, 2.0)];
      expect(mergeDut1(builtIn: builtIn, network: const []), same(builtIn));
    });

    test('сеть заменяет значения на совпадающих MJD', () {
      final builtIn = <(double, double)>[
        (10.0, 1.0),
        (20.0, 2.0),
        (30.0, 3.0),
      ];
      final net = <(double, double)>[(20.0, 9.9)];
      final out = mergeDut1(builtIn: builtIn, network: net);
      expect(out, [(10.0, 1.0), (20.0, 9.9), (30.0, 3.0)]);
    });

    test('сетевые точки встают между узлами встроенной таблицы', () {
      final builtIn = <(double, double)>[
        (10.0, 1.0),
        (20.0, 2.0),
      ];
      final net = <(double, double)>[
        (11.0, 1.1),
        (13.0, 1.3),
        (20.0, 9.9), // совпадение — побеждает сеть
      ];
      final out = mergeDut1(builtIn: builtIn, network: net);
      expect(out, [(10.0, 1.0), (11.0, 1.1), (13.0, 1.3), (20.0, 9.9)]);
    });

    test('сеть расширяет покрытие за последнюю встроенную точку', () {
      final builtIn = <(double, double)>[
        (10.0, 1.0),
        (20.0, 2.0),
      ];
      final net = <(double, double)>[
        (25.0, 2.5),
        (30.0, 3.0),
      ];
      final out = mergeDut1(builtIn: builtIn, network: net);
      expect(out.last, (30.0, 3.0));
      expect(out.length, 4);
      // Результат можно скармливать TableDut1Source: точность «сегодня».
      final src = TableDut1Source(out);
      final far = DateTime.utc(1858, 11, 17).add(const Duration(days: 29));
      expect(src.isPreciseFor(far), isTrue);
      expect(src.getDut1(far), closeTo(2.9, 0.15)); // интерполяция 25→30
    });

    test('сеть ДО первой встроенной точки игнорируется', () {
      final builtIn = <(double, double)>[
        (10.0, 1.0),
        (20.0, 2.0),
      ];
      final net = <(double, double)>[
        (5.0, 0.5), // раньше встроенной — финальные значения точнее
        (15.0, 1.5),
      ];
      final out = mergeDut1(builtIn: builtIn, network: net);
      expect(out, [(10.0, 1.0), (15.0, 1.5), (20.0, 2.0)]);
    });

    test('високосные дубли встроенной таблицы сохраняются', () {
      // 2016-12-31: (mjd, до скачка), (mjd, после) — как в kDut1Entries.
      final builtIn = <(double, double)>[
        (10.0, 0.4),
        (20.0, 0.3), // «до»
        (20.0, 1.3), // «после» — дубль MJD
        (30.0, 1.2),
      ];
      // Сеть касается только дальних точек, не високосного MJD.
      final net = <(double, double)>[
        (25.0, 1.25),
        (35.0, 1.1),
      ];
      final out = mergeDut1(builtIn: builtIn, network: net);
      // Дубль (20.0, …) остался двумя записями.
      expect(out.where((e) => e.$1 == 20.0).length, 2);
      expect(out, [
        (10.0, 0.4),
        (20.0, 0.3),
        (20.0, 1.3),
        (25.0, 1.25),
        (30.0, 1.2),
        (35.0, 1.1),
      ]);
    });

    test('интерполяция по объединению точнее, чем по встроенной', () {
      final builtIn = <(double, double)>[
        (10.0, 0.0),
        (40.0, 3.0), // грубая сетка: 0.1/день
      ];
      final day = DateTime.utc(1858, 11, 17).add(const Duration(days: 25));
      final base = TableDut1Source(builtIn).getDut1(day);
      expect(base, closeTo(1.5, 1e-9));
      // Сеть даёт точное значение в середине.
      final net = <(double, double)>[(25.0, 1.65)];
      final merged = mergeDut1(builtIn: builtIn, network: net);
      expect(TableDut1Source(merged).getDut1(day), closeTo(1.65, 1e-9));
    });
  });
}
