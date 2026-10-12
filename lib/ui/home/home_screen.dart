// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/astronomy/solar_calculator.dart';
import '../../core/geo/geo_point.dart';
import '../../core/time/format.dart';
import '../compare/compare_screen.dart';
import '../map/map_screen.dart';
import '../settings/settings_screen.dart';
import '../providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final point = ref.watch(pointAProvider);
    final snapshotAsync = ref.watch(solarSnapshotProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('СОЛНЦЕМЕР'),
        actions: [
          // ТЗ §14.1 Экран 1: кнопка «карта» (FR-08..FR-10).
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'Карта',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MapScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: 'Сравнить точки',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CompareScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Настройки',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: point == null
          ? _buildNoPoint(context, ref)
          : _buildWithPoint(context, ref, point, snapshotAsync),
    );
  }

  Widget _buildNoPoint(BuildContext context, WidgetRef ref) {
    // ТЗ FR-07: понятный статус при недоступной геолокации.
    final source = ref.watch(pointASourceProvider).value;
    final headline =
        source == PointASource.tracking ? 'Ожидание местоположения' : 'Геолокация недоступна';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              headline,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Введите координаты вручную или разрешите доступ к геолокации.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.my_location),
              label: const Text('Моё местоположение'),
              onPressed: () =>
                  ref.read(pointAProvider.notifier).startAutoLocation(),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.edit_location),
              label: const Text('Ввести координаты'),
              onPressed: () => _showEditPointDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithPoint(
      BuildContext context, WidgetRef ref, GeoPoint point, AsyncValue<SolarSnapshot> snap) {
    return snap.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
      data: (snap) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(solarSnapshotProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTimeCard(context, snap),
            const SizedBox(height: 16),
            _buildPointCard(context, ref, point),
            const SizedBox(height: 16),
            _buildSunCard(context, snap),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeCard(BuildContext context, SolarSnapshot snap) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              formatHms(snap.lat),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Истинное местное солнечное время',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              formatUtcOffset(snap.utcOffset),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Смещение от UTC',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            _buildDut1Row(context, snap),
          ],
        ),
      ),
    );
  }

  Widget _buildDut1Row(BuildContext context, SolarSnapshot snap) {
    if (snap.dut1Precise) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 4),
          Text(
            'Поправка DUT1 = ${snap.dut1Seconds >= 0 ? '+' : '−'}'
            '${snap.dut1Seconds.abs().toStringAsFixed(3)} с (данные IERS)',
            style: const TextStyle(fontSize: 12, color: Colors.green),
          ),
        ],
      );
    }
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.warning_amber, size: 16, color: Colors.orange),
        SizedBox(width: 4),
        Text(
          'Пониженная точность (DUT1 недоступен)',
          style: TextStyle(fontSize: 12, color: Colors.orange),
        ),
      ],
    );
  }

  Widget _buildPointCard(BuildContext context, WidgetRef ref, GeoPoint point) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_on),
              title: Text(point.label.isEmpty ? 'Точка A' : point.label),
              subtitle: Text(point.toString()),
            ),
            // ТЗ FR-07: пользователь должен видеть понятный статус источника
            // координат — «живые» они или застывшие.
            _buildSourceStatus(ref.watch(pointASourceProvider).value),
            // ТЗ FR-06/FR-14: индикация реалтайм-обновления координат.
            _buildFixStatus(ref),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('Моё местоположение'),
                  onPressed: () =>
                      ref.read(pointAProvider.notifier).startAutoLocation(),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Изменить координаты',
                  onPressed: () => _showEditPointDialog(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Индикация источника координат точки A (ТЗ FR-07).
  Widget _buildSourceStatus(PointASource? source) {
    if (source == null) return const SizedBox.shrink();
    late final IconData icon;
    late final String text;
    late final Color color;
    switch (source) {
      case PointASource.manual:
        icon = Icons.edit_location;
        text = 'Точка задана вручную — геолокация не используется';
        color = Colors.blueGrey;
      case PointASource.tracking:
        icon = Icons.my_location;
        text = 'Определяется автоматически — геолокация активна';
        color = Colors.green;
      case PointASource.geoUnavailable:
        icon = Icons.location_off;
        text = 'Геолокация недоступна, используется выбранная точка';
        color = Colors.orange;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: color),
            ),
          ),
        ],
      ),
    );
  }

  /// Индикация реалтайм-обновления координат (ТЗ FR-06, FR-14):
  /// «Обновлено 14:32:05 · ±12 м · gps», с пометкой «устарело».
  Widget _buildFixStatus(WidgetRef ref) {
    final source = ref.watch(pointASourceProvider).value;
    if (source != PointASource.tracking) return const SizedBox.shrink();
    final fix = ref.watch(pointAFixProvider);
    if (fix == null) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Icon(Icons.hourglass_empty, size: 14, color: Colors.grey),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Ожидание первого определения координат…',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }
    final age = DateTime.now().toUtc().difference(fix.timestampUtc);
    final stale = age > const Duration(seconds: 90);
    final acc = fix.accuracyMeters == null
        ? ''
        : ' · ±${fix.accuracyMeters!.round()} м';
    final prov = fix.provider == null ? '' : ' · ${fix.provider}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            stale ? Icons.warning_amber : Icons.sync,
            size: 14,
            color: stale ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              stale
                  ? 'Последнее обновление ${formatLocalHms(fix.timestampUtc)}'
                      ' устарело (${age.inMinutes} мин назад)'
                  : 'Обновлено ${formatLocalHms(fix.timestampUtc)}$acc$prov',
              style: TextStyle(
                fontSize: 11,
                color: stale ? Colors.orange : Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSunCard(BuildContext context, SolarSnapshot snap) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Восход / Заход',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'местное время (${formatLocalTzLabel()})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (snap.polarDay)
              const Text('☀ Полярный день')
            else if (snap.polarNight)
              const Text('🌑 Полярная ночь')
            else ...[
              _buildSunRow(
                context,
                'Восход',
                formatLocalEventTime(snap.nextSunriseUtc),
                formatLocalEventSub(snap.nextSunriseUtc),
              ),
              _buildSunRow(
                context,
                'Заход',
                formatLocalEventTime(snap.nextSunsetUtc),
                formatLocalEventSub(snap.nextSunsetUtc),
              ),
              _buildSunRow(
                context,
                'Полдень',
                formatLocalEventTime(snap.solarNoonUtc),
                formatLocalEventSub(snap.solarNoonUtc),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSunRow(
      BuildContext context, String label, String time, String sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: const TextStyle(
                    fontFamily: 'monospace', fontWeight: FontWeight.bold),
              ),
              if (sub.isNotEmpty)
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showEditPointDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final currentPoint = ref.read(pointAProvider);
    if (currentPoint != null) {
      controller.text = '${currentPoint.lat}, ${currentPoint.lon}';
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Координаты точки A'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '55.7558, 37.6173',
            labelText: 'Широта, Долгота',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final p = GeoPoint.tryParse(controller.text);
              if (p != null) {
                ref.read(pointAProvider.notifier).setPoint(p);
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Некорректные координаты')),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}
