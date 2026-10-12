// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dut1_source.dart';

/// Запись кэша DUT1, скачанного по сети (ТЗ §12.5: «кэширование данных
/// на устройстве»).
class Dut1CacheData {
  /// Точки `(mjd, dut1)` — отсортированы по mjd, без дублей.
  final List<(double, double)> entries;

  /// Момент загрузки (UTC).
  final DateTime fetchedAt;

  /// Откуда скачано (хост зеркала IERS) — для отображения пользователю.
  final String source;

  const Dut1CacheData({
    required this.entries,
    required this.fetchedAt,
    required this.source,
  });

  /// Кэш можно не обновлять, если он свежее [ttl].
  bool isFresh(Duration ttl, DateTime nowUtc) =>
      nowUtc.difference(fetchedAt) < ttl;
}

/// Сериализация кэша в SharedPreferences: `mjd:dut1;mjd:dut1;…`.
String encodeDut1Cache(List<(double, double)> entries) => entries
    .map((e) => '${e.$1}:${e.$2}')
    .join(';');

/// Обратная операция. Возвращает null при малейшем мусоре — кэш
/// выбрасывается целиком, встроенная таблица остаётся рабочей.
List<(double, double)>? decodeDut1Cache(String raw) {
  if (raw.isEmpty) return null;
  final out = <(double, double)>[];
  for (final part in raw.split(';')) {
    final pieces = part.split(':');
    if (pieces.length != 2) return null;
    final mjd = double.tryParse(pieces[0]);
    final dut1 = double.tryParse(pieces[1]);
    if (mjd == null || dut1 == null) return null;
    if (!mjd.isFinite || !dut1.isFinite) return null;
    out.add((mjd, dut1));
  }
  if (out.isEmpty) return null;
  for (var i = 1; i < out.length; i++) {
    if (out[i - 1].$1 >= out[i].$1) return null; // должен быть отсортирован
  }
  return out;
}

/// Слияние встроенной таблицы и сетевого кэша в одну для [TableDut1Source].
///
/// Правила:
/// - обе серии отсортированы; результат — упорядоченное объединение;
/// - на совпадающих MJD побеждает сеть (бюллетень свежее);
/// - сетевые точки попадают и МЕЖДУ узлами встроенной таблицы: у сети
///   разрешение сутки, у встроенной — декимировано до ~2 недель;
/// - сетевые точки за пределами покрытия встроенной таблицы расширяют
///   покрытие (основной смысл обновления: приложение не обновляли с 2027
///   года, а точные данные нужны «сегодня»);
/// - сетевые точки ДО первой встроенной игнорируются: там встроенная
///   таблица — финальные значения IERS, сеть же даёт лишь прогнозы.
///
/// Встроенные дубли MJD (високосные секунды: до/после скачка) сохраняются —
/// сетевое окно «сегодня ±800 суток» на исторические даты не попадает.
List<(double, double)> mergeDut1({
  required List<(double, double)> builtIn,
  required List<(double, double)> network,
}) {
  if (network.isEmpty) return builtIn;
  final first = builtIn.isEmpty ? null : builtIn.first.$1;
  final net = first == null
      ? network
      : network.where((e) => e.$1 >= first).toList();
  if (net.isEmpty) return builtIn;

  final out = <(double, double)>[];
  var i = 0;
  var j = 0;
  while (i < builtIn.length && j < net.length) {
    final a = builtIn[i];
    final n = net[j];
    if (a.$1 < n.$1) {
      out.add(a);
      i++;
    } else if (a.$1 > n.$1) {
      out.add(n);
      j++;
    } else {
      out.add(n); // равные MJD — побеждает сеть
      i++;
      j++;
    }
  }
  out.addAll(builtIn.skip(i));
  out.addAll(net.skip(j));
  return out;
}
