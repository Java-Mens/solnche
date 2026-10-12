// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_repository.dart';

/// Провайдер репозитория настроек.
///
/// Переопределяется в ProviderScope из main() после загрузки
/// SharedPreferences.
final settingsProvider = Provider<SettingsRepository>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});
