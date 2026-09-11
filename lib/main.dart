// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/settings/settings_repository.dart';
import 'ui/home/home_screen.dart';
import 'ui/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsRepository.create();
  runApp(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWithValue(settings),
      ],
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
