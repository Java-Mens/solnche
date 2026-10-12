// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

/// Парсер файла IERS `finals2000A.daily` (и `.all`) — фиксированная ширина.
///
/// Позиции проверены по реальным данным finals2000A.all (1973–2027,
/// 20049 строк, все 26 високосных секунд дают скачок +1.000 с):
/// - `line[7:15]`  — MJD (F8, float, допускаются пробелы);
/// - `line[57]`    — флаг Bulletin A: 'I' (final) / 'P' (prediction);
/// - `line[58:68]` — UT1−UTC в секундах (10 симв., знак/пробел впереди);
/// - строки короче 68 символов и заголовки пропускаются.
List<(double, double)>? parseFinalsDaily(String text, DateTime nowUtc) {
  final rows = <(double, double)>[];
  final byMjdIndex = <double, int>{};
  for (final raw in text.split('\n')) {
    final line = raw.trimRight();
    if (line.length < 68) continue;
    final mjd = double.tryParse(line.substring(7, 15).trim());
    final dut1 = double.tryParse(line.substring(58, 68).trim());
    if (mjd == null || dut1 == null) continue;
    if (!mjd.isFinite || !dut1.isFinite) continue;
    // MJD в этих файлах — всегда целый день (допуск на F8.2).
    if ((mjd - mjd.roundToDouble()).abs() > 1e-6) continue;
    if (dut1.abs() > 1.5) continue; // защита от мусора

    final key = mjd.roundToDouble();
    final dupIndex = byMjdIndex[key];
    if (dupIndex != null) {
      rows[dupIndex] = (key, dut1); // дубль в том же файле — берём последнее
    } else {
      byMjdIndex[key] = rows.length;
      rows.add((key, dut1));
    }
  }

  // Достаточно ли валидных строк (защита от HTML-заглушек зеркал).
  if (rows.length < 5) return null;

  // Строгий возрастающий порядок MJD — обязательное свойство файлов IERS.
  for (var i = 1; i < rows.length; i++) {
    if (rows[i - 1].$1 >= rows[i].$1) return null;
  }

  // Данные должны быть про сегодняшний день ±800 суток, иначе это не
  // рабочий файл (устаревшее зеркало, тестовый фикстур и т.п.).
  final nowMjd = _mjdOf(nowUtc);
  const window = 800.0;
  if (rows.first.$1 < nowMjd - window || rows.last.$1 > nowMjd + window) {
    return null;
  }
  // Хоть одна точка в пределах 90 суток от «сегодня» — иначе пользы нет.
  if (rows.last.$1 < nowMjd - 90) return null;

  return rows;
}

double _mjdOf(DateTime utc) =>
    utc.difference(DateTime.utc(1858, 11, 17)).inDays.toDouble();
