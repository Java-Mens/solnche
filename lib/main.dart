// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/dut1/dut1_sync.dart';
import 'data/settings/settings_repository.dart';
import 'ui/home/home_screen.dart';
import 'ui/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsRepository.create();
  final container = ProviderContainer(
    overrides: [settingsProvider.overrideWithValue(settings)],
  );
  // Обновление DUT1 по сети при старте (ТЗ §12.5, §13.3) — в фоне,
  // не блокируя первый кадр. При выключенной настройке / отсутствии
  // сети тихо остаётся встроенная таблица (ТЗ §20.3).
  unawaited(container.read(dut1SyncProvider.notifier).refreshFromStartup());
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SolntsemerApp(),
    ),
  );
}

class SolntsemerApp extends StatelessWidget {
  const SolntsemerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'СОЛНЦЕМЕР',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
