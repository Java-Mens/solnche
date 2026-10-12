// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_provider.dart';
import 'dut1_cache.dart';
import 'dut1_source.dart';
import 'dut1_table.dart';

/// Провайдер источника DUT1 (ТЗ §12.5).
///
/// База — встроенная таблица из данных IERS Bulletin A (finals2000A),
/// обновляется вместе с приложением. Если на устройстве есть сетевой
/// кэш (обновляется Dut1SyncNotifier'ом — см. dut1_sync.dart), значения
/// кэша свежее: на совпадающих MJD побеждает кэш, покрытие расширяется.
///
/// За пределами покрытия [TableDut1Source.isPreciseFor] возвращает false,
/// и интерфейс показывает индикацию пониженной точности (ТЗ §12.3).
final dut1Provider = Provider<Dut1Source>((ref) {
  final settings = ref.watch(settingsProvider);
  final cache = settings.getDut1Cache();
  final entries = cache == null
      ? kDut1Entries
      : mergeDut1(builtIn: kDut1Entries, network: cache.entries);
  return TableDut1Source(entries);
});
