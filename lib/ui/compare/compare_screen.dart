// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/astronomy/solar_calculator.dart';
import '../../core/geo/geo_point.dart';
import '../../core/time/format.dart';
import '../providers.dart';

class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointA = ref.watch(pointAProvider);
    final pointB = ref.watch(pointBProvider);
    final snapA = ref.watch(solarSnapshotProvider);
    final snapB = ref.watch(solarSnapshotBProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сравнение точек'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_vert),
            tooltip: 'Поменять местами',
            onPressed: () => _swapPoints(ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPointCard(context, ref, 'Точка A', pointA, snapA, isA: true),
          const SizedBox(height: 16),
          _buildPointCard(context, ref, 'Точка B', pointB, snapB, isA: false),
          const SizedBox(height: 16),
          _buildDiffCard(context, snapA, snapB),
        ],
      ),
    );
  }

  Widget _buildPointCard(
    BuildContext context,
    WidgetRef ref,
    String title,
    GeoPoint? point,
    AsyncValue<SolarSnapshot> snapAsync,
    {required bool isA}
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editPoint(context, ref, isA),
                ),
              ],
            ),
            if (point == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Не задана', style: TextStyle(color: Colors.grey)),
              )
            else ...[
              Text(point.toString(), style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              snapAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Ошибка: $e'),
                data: (snap) => Column(
                  children: [
                    Text(
                      formatHms(snap.lat),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatUtcOffset(snap.utcOffset),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiffCard(
      BuildContext context, AsyncValue<SolarSnapshot> snapA, AsyncValue<SolarSnapshot> snapB) {
    if (snapA is! AsyncData || snapB is! AsyncData) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Задайте обе точки для сравнения'),
        ),
      );
    }

    final a = snapA.value;
    final b = snapB.value;
    if (a == null || b == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Задайте обе точки для сравнения'),
        ),
      );
    }

    final diff = a.lat - b.lat;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('Разница истинного времени'),
            const SizedBox(height: 8),
            Text(
              formatDiff(diff),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _swapPoints(WidgetRef ref) {
    final a = ref.read(pointAProvider);
    final b = ref.read(pointBProvider);
    ref.read(pointAProvider.notifier).setPoint(b);
    ref.read(pointBProvider.notifier).setPoint(a);
  }

  Future<void> _editPoint(BuildContext context, WidgetRef ref, bool isA) async {
    final controller = TextEditingController();
    final currentPoint = isA ? ref.read(pointAProvider) : ref.read(pointBProvider);
    if (currentPoint != null) {
      controller.text = '${currentPoint.lat}, ${currentPoint.lon}';
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Координаты ${isA ? "точки A" : "точки B"}'),
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
                if (isA) {
                  ref.read(pointAProvider.notifier).setPoint(p);
                } else {
                  ref.read(pointBProvider.notifier).setPoint(p);
                }
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
