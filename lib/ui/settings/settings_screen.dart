// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/astronomy/solar_calculator.dart';
import '../../core/geo/geo_point.dart';
import '../../core/time/format.dart';
import '../../data/dut1/dut1_source.dart';
import '../../data/dut1/dut1_sync.dart';
import '../../data/notification/notification_repository.dart';
import '../../data/widget/widget_repository.dart';
import '../providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final sunriseMode = ref.watch(sunriseModeProvider);
    final dut1 = ref.watch(dut1Provider);
    final sync = ref.watch(dut1SyncProvider);
    final notificationOn = ref.watch(notificationProvider);
    final notificationPoint = ref.watch(notificationPointProvider);
    final widgetConfig = ref.watch(widgetConfigProvider);

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
          // ── Сетевой поиск (ТЗ FR-12) ───────────────────────────────
          SwitchListTile(
            title: const Text('Поиск по названию (Nominatim)'),
            subtitle: const Text(
                'Открытые данные OSM · не чаще 1 запроса в секунду · '
                'только по вашему запросу'),
            value: settings.searchNetworkEnabled,
            onChanged: (v) async {
              await settings.setSearchNetworkEnabled(v);
              setState(() {});
            },
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
          if (_isAndroid) ...[
            const Divider(),
            // ── Постоянное уведомление (ТЗ FR-20..FR-23) ─────────────
            SwitchListTile(
              title: const Text('Постоянное уведомление'),
              subtitle: const Text(
                  'Показывает истинное время и смещение от UTC выбранной '
                  'точки; обновляется каждую секунду, пока приложение '
                  'запущено (foreground service)'),
              value: notificationOn,
              onChanged: (v) async {
                final ok = await ref
                    .read(notificationProvider.notifier)
                    .setEnabled(v);
                if (!ok && v && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Разрешение на уведомления не выдано — '
                          'функция отключена (приложение работает дальше)'),
                    ),
                  );
                }
                if (mounted) setState(() {});
              },
            ),
            if (notificationOn)
              ListTile(
                title: const Text('Точка в уведомлении'),
                subtitle: Text(notificationPoint == NotificationPoint.pointA
                    ? 'Точка A (текущее местоположение или ручная)'
                    : 'Точка B (сравнение)'),
                leading: const Icon(Icons.notifications_active, size: 20),
                onTap: () => _showNotificationPointDialog(context),
              ),
            const Divider(),
            // ── Виджет рабочего стола (ТЗ FR-24..FR-27) ─────────────
            ListTile(
              title: const Text('Виджет рабочего стола'),
              subtitle: const Text(
                  'Добавьте виджет «СОЛНЦЕМЕР» на рабочий стол Android — '
                  'он покажет истинное время точки. Здесь можно выбрать, '
                  'какую точку и какие элементы показывать'),
              leading: const Icon(Icons.widgets, size: 20),
            ),
            ListTile(
              title: const Text('Точка виджета'),
              subtitle: Text(switch (widgetConfig.source) {
                WidgetPointSource.pointA => 'Точка A (следует за приложением)',
                WidgetPointSource.pointB => 'Точка B (сравнение)',
                WidgetPointSource.fixed => 'Фиксированная точка',
              }),
              onTap: () => _showWidgetSourceDialog(context),
            ),
            if (widgetConfig.source == WidgetPointSource.fixed)
              ListTile(
                title: const Text('Фиксированная точка'),
                subtitle: Text(widgetConfig.fixedPoint?.toString() ??
                    'не задана — введите координаты'),
                onTap: () => _showWidgetFixedPointDialog(context),
              ),
            SwitchListTile(
              title: const Text('Виджет: показывать смещение от UTC'),
              value: widgetConfig.showOffset,
              onChanged: (v) async {
                await ref
                    .read(widgetConfigProvider.notifier)
                    .setShowOffset(v);
                setState(() {});
              },
            ),
            SwitchListTile(
              title: const Text('Виджет: показывать восход и заход'),
              value: widgetConfig.showSun,
              onChanged: (v) async {
                await ref.read(widgetConfigProvider.notifier).setShowSun(v);
                setState(() {});
              },
            ),
          ],
          const Divider(),
          const ListTile(
            title: Text('О приложении'),
            subtitle: Text('СОЛНЦЕМЕР v0.1.0\n GPLv3'),
          ),
        ],
      ),
    );
  }

  Future<void> _showNotificationPointDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Точка в уведомлении'),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              await ref
                  .read(notificationPointProvider.notifier)
                  .setPoint(NotificationPoint.pointA);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Точка A — текущее местоположение или ручная'),
          ),
          SimpleDialogOption(
            onPressed: () async {
              await ref
                  .read(notificationPointProvider.notifier)
                  .setPoint(NotificationPoint.pointB);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Точка B — точка сравнения'),
          ),
        ],
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _showWidgetSourceDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Какую точку показывает виджет'),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              await ref
                  .read(widgetConfigProvider.notifier)
                  .setSource(WidgetPointSource.pointA);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Точку A — как в приложении (текущее '
                'местоположение или последняя выбранная)'),
          ),
          SimpleDialogOption(
            onPressed: () async {
              await ref
                  .read(widgetConfigProvider.notifier)
                  .setSource(WidgetPointSource.pointB);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Точку B — точка сравнения'),
          ),
          SimpleDialogOption(
            onPressed: () async {
              await ref
                  .read(widgetConfigProvider.notifier)
                  .setSource(WidgetPointSource.fixed);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Фиксированную точку — задать координаты'),
          ),
        ],
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _showWidgetFixedPointDialog(BuildContext context) async {
    final controller = TextEditingController();
    final current =
        ref.read(widgetConfigProvider).fixedPoint;
    if (current != null) {
      controller.text = '${current.lat}, ${current.lon}';
    }
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Фиксированная точка виджета'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '55.7558, 37.6173',
            labelText: 'Широта, Долгота',
          ),
          keyboardType: const TextInputType.numberWithOptions(
              decimal: true, signed: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final p = GeoPoint.tryParse(controller.text);
              if (p == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Некорректные координаты')),
                );
                return;
              }
              await ref
                  .read(widgetConfigProvider.notifier)
                  .setFixedPoint(p);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (mounted) setState(() {});
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
