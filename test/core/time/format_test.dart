// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:solntsemer/core/time/format.dart';

Duration hms(int h, int m, int s) =>
    Duration(hours: h, minutes: m, seconds: s);

void main() {
  group('formatHms', () {
    test('basic', () {
      expect(formatHms(hms(13, 45, 26)), '13:45:26');
    });
    test('wraps at 24h', () {
      expect(formatHms(hms(25, 0, 0)), '01:00:00');
    });
    test('negative Duration treated as absolute', () {
      expect(formatHms(const Duration(hours: -2, minutes: -30)), '02:30:00');
    });
    test('zero', () {
      expect(formatHms(Duration.zero), '00:00:00');
    });
  });

  group('formatUtcOffset', () {
    test('positive', () {
      expect(formatUtcOffset(hms(2, 13, 45)), 'UTC+02:13:45');
    });
    test('negative', () {
      expect(formatUtcOffset(hms(0, -16, -21)), 'UTC−00:16:21');
    });
    test('zero', () {
      expect(formatUtcOffset(Duration.zero), 'UTC+00:00:00');
    });
  });

  group('formatDiff', () {
    test('normalizes +25h to +01h', () {
      expect(formatDiff(hms(25, 0, 0)), '+01:00:00');
    });
    test('normalizes -13h to +11h', () {
      // -13h + 24h = 11h
      expect(formatDiff(hms(-13, 0, 0)), '+11:00:00');
    });
    test('small negative', () {
      expect(formatDiff(hms(0, -12, -3)), '−00:12:03');
    });
  });

  group('formatUtcTime', () {
    test('formats non-null', () {
      expect(formatUtcTime(DateTime.utc(2024, 6, 21, 13, 45, 26)), '13:45');
    });
    test('with seconds', () {
      expect(
        formatUtcTime(DateTime.utc(2024, 6, 21, 13, 45, 26),
            withSeconds: true),
        '13:45:26',
      );
    });
    test('null returns em dash', () {
      expect(formatUtcTime(null), '—');
    });
  });
}
