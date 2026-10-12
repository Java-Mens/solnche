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
  // Создаём долгоживущие контроллеры уведомления и виджета (ТЗ FR-20..27):
  // если уведомление было включено в прошлый запуск — служба стартует снова.
  unawaited(container.read(widgetConfigProvider.notifier).push());
  // Читаем состояние уведомления после настройки виджета, чтобы пуш
  // конфигурации не обогнал старт службы.
  container.read(notificationProvider);
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
      // Биндер оборачивает все экраны, включая новые маршруты, и остаётся
      // смонтированным, пока приложение живо (в том числе в фоне). Riverpod 3
      // паузит потоки без активных слушателей — активная подписка здесь
      // не даёт секундному тикеру остановиться, поэтому уведомление
      // обновляется каждую секунду и вне главного экрана (ТЗ FR-21).
      builder: (context, child) => _SystemBinder(child: child),
    );
  }
}

class _SystemBinder extends ConsumerWidget {
  const _SystemBinder({this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Активные подписки на долгоживущие контроллеры (см. комментарий выше).
    ref.watch(notificationProvider);
    ref.watch(widgetConfigProvider);
    return child ?? const SizedBox.shrink();
  }
}
