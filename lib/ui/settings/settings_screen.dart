// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/astronomy/solar_calculator.dart';
import '../../core/time/format.dart';
import '../../data/dut1/dut1_source.dart';
import '../../data/dut1/dut1_sync.dart';
import '../providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final sunriseMode = ref.watch(sunriseModeProvider);
    final dut1 = ref.watch(dut1Provider);
    final sync = ref.watch(dut1SyncProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Интервал обновления времени'),
            subtitle: Text('${settings.timeUpdateIntervalSeconds} с'),
            trailing: DropdownButton<int>(
              value: settings.timeUpdateIntervalSeconds,
              items: [1, 2, 5, 10, 30]
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v с')))
                  .toList(),
              onChanged: (v) async {
                if (v != null) {
                  await settings.setTimeUpdateIntervalSeconds(v);
                  // Периодический поток захватывает интервал при создании:
                  // пересоздаём провайдеры снимков, чтобы новый интервал
                  // применился без перезапуска приложения.
                  ref.invalidate(solarSnapshotProvider);
                  ref.invalidate(solarSnapshotBProvider);
                  setState(() {});
                }
              },
            ),
          ),
          ListTile(
            title: const Text('Интервал геолокации'),
            subtitle: Text('${settings.locationIntervalSeconds} с'),
            trailing: DropdownButton<int>(
              value: settings.locationIntervalSeconds,
              items: [1, 5, 15, 30, 60]
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v с')))
                  .toList(),
              onChanged: (v) async {
                if (v != null) {
                  await settings.setLocationIntervalSeconds(v);
                  // PointANotifier читает интервал при старте слежения.
                  ref.invalidate(pointAProvider);
                  setState(() {});
                }
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Режим восхода/захода'),
            subtitle: Text(sunriseMode == SunriseMode.observed
                ? 'Наблюдаемый (−0.833°)'
                : 'Геометрический (0°)'),
            onTap: () => _showSunriseModeDialog(context),
          ),
          const Divider(),
          // ── DUT1 (ТЗ §12.5: встроенная таблица + обновление по сети) ──
          SwitchListTile(
            title: const Text('Обновлять DUT1 по сети'),
            subtitle: const Text(
                'Скачивать свежий бюллетень IERS (finals2000A.daily) раз в сутки'),
            value: settings.dut1NetworkEnabled,
            onChanged: (v) async {
              await ref.read(dut1SyncProvider.notifier).setEnabled(v);
              setState(() {});
            },
          ),
          ListTile(
            leading: _syncIcon(sync),
            title: Text(_syncTitle(sync)),
            subtitle: Text(_syncSubtitle(sync)),
            trailing: settings.dut1NetworkEnabled
                ? IconButton(
                    icon: sync.kind == Dut1SyncKind.checking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    tooltip: 'Обновить сейчас',
                    onPressed: sync.kind == Dut1SyncKind.checking
                        ? null
                        : () async {
                            await ref
                                .read(dut1SyncProvider.notifier)
                                .refreshNow();
                            setState(() {});
                          },
                  )
                : null,
          ),
          const Divider(),
          ListTile(
            title: const Text('Источник DUT1'),
            subtitle: Text(_dut1Description(dut1)),
            leading: Icon(
              dut1.isPrecise ? Icons.check_circle : Icons.warning_amber,
              color: dut1.isPrecise ? Colors.green : Colors.orange,
            ),
          ),
          const Divider(),
          const ListTile(
            title: Text('О приложении'),
            subtitle: Text('СОЛНЦЕМЕР v0.1.0\n GPLv3'),
          ),
        ],
      ),
    );
  }

  Widget _syncIcon(Dut1SyncState sync) {
    switch (sync.kind) {
      case Dut1SyncKind.updated:
      case Dut1SyncKind.upToDate:
        return const Icon(Icons.cloud_done, color: Colors.green, size: 20);
      case Dut1SyncKind.checking:
        return const Icon(Icons.cloud_download,
            color: Colors.blueGrey, size: 20);
      case Dut1SyncKind.failed:
        return const Icon(Icons.cloud_off, color: Colors.orange, size: 20);
      case Dut1SyncKind.disabled:
        return const Icon(Icons.pause_circle, color: Colors.grey, size: 20);
      case Dut1SyncKind.idle:
        return const Icon(Icons.cloud_outlined, color: Colors.grey, size: 20);
    }
  }

  String _syncTitle(Dut1SyncState sync) {
    switch (sync.kind) {
      case Dut1SyncKind.updated:
        return 'Обновлено';
      case Dut1SyncKind.upToDate:
        return 'Кэш свежий (обновлять не нужно)';
      case Dut1SyncKind.checking:
        return 'Обновляю…';
      case Dut1SyncKind.failed:
        return 'Не удалось обновить';
      case Dut1SyncKind.disabled:
        return 'Обновление по сети выключено';
      case Dut1SyncKind.idle:
        return 'Синхронизация DUT1';
    }
  }

  String _syncSubtitle(Dut1SyncState sync) {
    final when = sync.fetchedAt == null
        ? null
        : formatLocalEventTime(sync.fetchedAt);
    switch (sync.kind) {
      case Dut1SyncKind.updated:
        return '${when ?? '—'} · ${sync.entryCount} записей · '
            '${sync.source}';
      case Dut1SyncKind.upToDate:
        return 'Последняя загрузка: ${when ?? '—'} · ${sync.source}';
      case Dut1SyncKind.checking:
        return sync.hasCache
            ? 'Используется кэш от ${when ?? '—'}'
            : 'Используется встроенная таблица';
      case Dut1SyncKind.failed:
        return sync.hasCache
            ? 'Нет сети — работает кэш от ${when ?? '—'}'
            : 'Нет сети — работает встроенная таблица (2015–2027)';
      case Dut1SyncKind.disabled:
        return sync.hasCache
            ? 'Сохранённый кэш от ${when ?? '—'} продолжает использоваться'
            : 'Работает встроенная таблица IERS (2015–2027)';
      case Dut1SyncKind.idle:
        return 'Ещё не проверялось';
    }
  }

  String _dut1Description(Dut1Source dut1) {
    final now = DateTime.now().toUtc();
    if (dut1.isPreciseFor(now)) {
      final v = dut1.getDut1(now);
      return '${dut1.description}\n'
          'Сейчас: DUT1 = ${v >= 0 ? '+' : '−'}${v.abs().toStringAsFixed(4)} с';
    }
    return '${dut1.description}\nСейчас нет данных — UTC ≈ UT1 (±0.9 с)';
  }

  Future<void> _showSunriseModeDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Режим восхода/захода'),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              await ref
                  .read(sunriseModeProvider.notifier)
                  .setMode(SunriseMode.observed);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Наблюдаемый (−0.833°)'),
          ),
          SimpleDialogOption(
            onPressed: () async {
              await ref
                  .read(sunriseModeProvider.notifier)
                  .setMode(SunriseMode.geometric);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Геометрический (0°)'),
          ),
        ],
      ),
    );
    if (mounted) setState(() {});
  }
}
