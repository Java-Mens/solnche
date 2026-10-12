// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_provider.dart';
import 'dut1_cache.dart';
import 'dut1_provider.dart';
import 'finals_daily.dart';

/// Зеркала IERS Bulletin A (finals2000A.daily), только HTTPS (ТЗ §19.3).
/// Порядок — от основного к запасным.
final kDut1Mirrors = <Uri>[
  Uri.https('maia.usno.navy.mil', '/sera/finals2000A.daily'),
  Uri.https('hpiers.obspm.fr', '/iers/eop/eopc04/finals2000A.daily'),
];

/// Политика обновления кэша DUT1 (ТЗ §12.5 «кэширование на устройстве»).
const kDut1CacheTtl = Duration(hours: 24);

const _kUserAgent = 'Solntsemer/0.1 (dev.atom42.solntsemer; GPLv3+)';

/// Состояние синхронизации DUT1 по сети — для экрана настроек.
enum Dut1SyncKind { idle, checking, upToDate, updated, failed, disabled }

class Dut1SyncState {
  final Dut1SyncKind kind;
  final DateTime? fetchedAt;
  final int? entryCount;
  final String? source;
  final bool hasCache;

  const Dut1SyncState({
    required this.kind,
    this.fetchedAt,
    this.entryCount,
    this.source,
    this.hasCache = false,
  });

  const Dut1SyncState.idle() : this(kind: Dut1SyncKind.idle);
}

final dut1SyncProvider =
    NotifierProvider<Dut1SyncNotifier, Dut1SyncState>(Dut1SyncNotifier.new);

/// Фоновое обновление DUT1 по сети (ТЗ §12.5, §13.3, §19.3).
///
/// Сценарий: при старте приложения и по кнопке «Обновить сейчас»
/// скачивается finals2000A.daily с зеркал IERS, парсится, кэшируется
/// в SharedPreferences (TTL 24 ч) и инвалидирует [dut1Provider] —
/// значения DUT1 в приложении обновляются сами. Отключается
/// переключателем в настройках; при отсутствии сети используется
/// кэш или встроенная таблица — приложение работает офлайн (ТЗ §20.3).
class Dut1SyncNotifier extends Notifier<Dut1SyncState> {
  bool _running = false;

  @override
  Dut1SyncState build() => const Dut1SyncState.idle();

  /// Вызывается один раз из main() при запуске приложения.
  Future<void> refreshFromStartup() => _refresh(force: false);

  /// Кнопка «Обновить сейчас» в настройках.
  Future<void> refreshNow() => _refresh(force: true);

  /// Переключатель «Обновлять DUT1 по сети».
  Future<void> setEnabled(bool enabled) async {
    await ref.read(settingsProvider).setDut1NetworkEnabled(enabled);
    if (enabled) {
      await _refresh(force: true);
    } else {
      state = Dut1SyncState(
        kind: Dut1SyncKind.disabled,
        hasCache: _cache() != null,
      );
    }
  }

  Dut1CacheData? _cache() => ref.read(settingsProvider).getDut1Cache();

  Future<void> _refresh({required bool force}) async {
    if (_running) return;
    final settings = ref.read(settingsProvider);
    if (!settings.dut1NetworkEnabled) {
      state = Dut1SyncState(
        kind: Dut1SyncKind.disabled,
        hasCache: _cache() != null,
      );
      return;
    }

    final now = DateTime.now().toUtc();
    final cache = _cache();
    if (!force && cache != null && cache.isFresh(kDut1CacheTtl, now)) {
      state = Dut1SyncState(
        kind: Dut1SyncKind.upToDate,
        fetchedAt: cache.fetchedAt,
        entryCount: cache.entries.length,
        source: cache.source,
        hasCache: true,
      );
      return;
    }

    _running = true;
    state = Dut1SyncState(
      kind: Dut1SyncKind.checking,
      fetchedAt: cache?.fetchedAt,
      source: cache?.source,
      hasCache: cache != null,
    );
    try {
      for (final url in kDut1Mirrors) {
        try {
          final text = await _httpGet(url).timeout(const Duration(seconds: 15));
          final entries = parseFinalsDaily(text, DateTime.now().toUtc());
          if (entries == null) continue; // не похоже на файл — пробуем дальше
          final fetchedAt = DateTime.now().toUtc();
          final source = url.host;
          await settings.setDut1Cache(
            entries: entries,
            fetchedAt: fetchedAt,
            source: source,
          );
          ref.invalidate(dut1Provider);
          state = Dut1SyncState(
            kind: Dut1SyncKind.updated,
            fetchedAt: fetchedAt,
            entryCount: entries.length,
            source: source,
            hasCache: true,
          );
          return;
        } catch (_) {
          // следующее зеркало
        }
      }
      state = Dut1SyncState(
        kind: Dut1SyncKind.failed,
        fetchedAt: cache?.fetchedAt,
        entryCount: cache?.entries.length,
        source: cache?.source,
        hasCache: cache != null,
      );
    } finally {
      _running = false;
    }
  }

  Future<String> _httpGet(Uri url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(url);
      request.headers.set(HttpHeaders.userAgentHeader, _kUserAgent);
      request.headers.set(HttpHeaders.acceptHeader, 'text/plain');
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}: ${url.host}');
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > 2 * 1024 * 1024) {
          throw HttpException('ответ больше 2 МБ: ${url.host}');
        }
      }
      return utf8.decode(bytes);
    } finally {
      client.close();
    }
  }
}
