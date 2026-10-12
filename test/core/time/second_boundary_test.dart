// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:solntsemer/core/time/second_boundary.dart';

void main() {
  group('delayToNextSecondBoundary', () {
    test('начало секунды → почти полная секунда', () {
      final now = DateTime(2026, 10, 12, 14, 32, 5, 0);
      expect(delayToNextSecondBoundary(now), 1000);
    });

    test('середина секунды → половина', () {
      final now = DateTime(2026, 10, 12, 14, 32, 5, 500);
      expect(delayToNextSecondBoundary(now), 500);
    });

    test('конец секунды → минимум 1 мс', () {
      final now = DateTime(2026, 10, 12, 14, 32, 5, 999);
      expect(delayToNextSecondBoundary(now), 1);
    });

    test('результат всегда в 1..1000', () {
      for (var ms = 0; ms < 1000; ms += 7) {
        final now = DateTime(2026, 10, 12, 14, 32, 5, ms);
        final d = delayToNextSecondBoundary(now);
        expect(d, greaterThanOrEqualTo(1));
        expect(d, lessThanOrEqualTo(1000));
        // Сумма точно попадает в границу следующей секунды.
        expect(ms + d, 1000);
      }
    });
  });
}
