// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/astronomy/solar_calculator.dart';
import '../../core/geo/geo_point.dart';
import '../../core/time/format.dart';
import '../compare/compare_screen.dart';
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Геолокация недоступна',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Введите координаты вручную или разрешите доступ к геолокации.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
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
            if (!snap.dut1Precise) ...[
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                  SizedBox(width: 4),
                  Text(
                    'Пониженная точность (DUT1 недоступен)',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPointCard(BuildContext context, WidgetRef ref, GeoPoint point) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.location_on),
        title: Text(point.label.isEmpty ? 'Точка A' : point.label),
        subtitle: Text(point.toString()),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _showEditPointDialog(context, ref),
        ),
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
            Text(
              'Восход / Заход',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (snap.polarDay)
              const Text('☀ Полярный день')
            else if (snap.polarNight)
              const Text('🌑 Полярная ночь')
            else ...[
              _buildSunRow('Восход', formatUtcTime(snap.nextSunriseUtc, withSeconds: true)),
              _buildSunRow('Заход', formatUtcTime(snap.nextSunsetUtc, withSeconds: true)),
              _buildSunRow('Полдень', formatUtcTime(snap.solarNoonUtc, withSeconds: true)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSunRow(String label, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            time,
            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
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
