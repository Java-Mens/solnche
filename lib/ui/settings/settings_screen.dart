// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/astronomy/solar_calculator.dart';
import '../providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final sunriseMode = ref.watch(sunriseModeProvider);

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
              items: [1, 2, 5, 10, 30].map((v) => DropdownMenuItem(value: v, child: Text('$v с'))).toList(),
              onChanged: (v) async {
                if (v != null) {
                  await settings.setTimeUpdateIntervalSeconds(v);
                  ref.invalidate(sunriseModeProvider);
                }
              },
            ),
          ),
          ListTile(
            title: const Text('Интервал геолокации'),
            subtitle: Text('${settings.locationIntervalSeconds} с'),
            trailing: DropdownButton<int>(
              value: settings.locationIntervalSeconds,
              items: [1, 5, 15, 30, 60].map((v) => DropdownMenuItem(value: v, child: Text('$v с'))).toList(),
              onChanged: (v) async {
                if (v != null) {
                  await settings.setLocationIntervalSeconds(v);
                  ref.invalidate(sunriseModeProvider);
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
            onTap: () => _showSunriseModeDialog(context, ref),
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

  Future<void> _showSunriseModeDialog(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Режим восхода/захода'),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              await ref.read(sunriseModeProvider.notifier).setMode(SunriseMode.observed);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Наблюдаемый (−0.833°)'),
          ),
          SimpleDialogOption(
            onPressed: () async {
              await ref.read(sunriseModeProvider.notifier).setMode(SunriseMode.geometric);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Геометрический (0°)'),
          ),
        ],
      ),
    );
  }
}
