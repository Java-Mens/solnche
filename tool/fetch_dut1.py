#!/usr/bin/env python3
# Copyright (C) 2026 Atom42 and contributors
# SPDX-License-Identifier: GPL-3.0-or-later
"""Генератор lib/data/dut1/dut1_table.dart из данных IERS Bulletin A.

Скачивает файлы Rapid Service/Prediction Center (USNO):
  - finals2000A.all   — финальные значения EOP с 1973 года;
  - finals2000A.daily — свежие финалы + прогноз (~90 суток).

Выход: встроенная таблица DUT1 = UT1 − UTC с адаптивной децимацией
(Ramer–Douglas–Peucker, допуск 2 мс) и таблица високосных секунд
(TAI − UTC). Високосные скачки DUT1 кодируются дублями MJD:
(mjd, значение_до), (mjd, значение_после) — бинарный поиск
TableDut1Source корректно обрабатывает такие дубли.

Запуск: python3 tool/fetch_dut1.py
"""
import sys
import urllib.request
from datetime import date, timedelta

URLS = [
    'https://maia.usno.navy.mil/ser7/finals2000A.all',
    'https://maia.usno.navy.mil/ser7/finals2000A.daily',
]
OUT = 'lib/data/dut1/dut1_table.dart'
MJD_START = 57023  # 2015-01-01 (включает ступени високосных секунд 2015 и 2016)
TOL_S = 0.002      # допуск линейной интерполяции, 2 мс

# Официальная история високосных секунд (IERS Bulletin C).
LEAPS = [
    (date(1972, 1, 1), 10), (date(1972, 7, 1), 11), (date(1973, 1, 1), 12),
    (date(1974, 1, 1), 13), (date(1975, 1, 1), 14), (date(1976, 1, 1), 15),
    (date(1977, 1, 1), 16), (date(1978, 1, 1), 17), (date(1979, 1, 1), 18),
    (date(1980, 1, 1), 19), (date(1981, 7, 1), 20), (date(1982, 7, 1), 21),
    (date(1983, 7, 1), 22), (date(1985, 7, 1), 23), (date(1988, 1, 1), 24),
    (date(1990, 1, 1), 25), (date(1991, 1, 1), 26), (date(1992, 7, 1), 27),
    (date(1993, 7, 1), 28), (date(1994, 7, 1), 29), (date(1996, 1, 1), 30),
    (date(1997, 7, 1), 31), (date(1999, 1, 1), 32), (date(2006, 1, 1), 33),
    (date(2009, 1, 1), 34), (date(2012, 7, 1), 35), (date(2015, 7, 1), 36),
    (date(2017, 1, 1), 37),
]

EPOCH = date(1858, 11, 17)


def to_mjd(d):
    return (d - EPOCH).days


def to_date(mjd):
    return EPOCH + timedelta(days=int(mjd))


def fetch(url):
    print(f'Загрузка {url} ...')
    req = urllib.request.Request(url, headers={'User-Agent': 'solntsemer-dut1-gen'})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read().decode('ascii', errors='replace').splitlines()


def parse_line(line):
    """finals2000A, фиксированные позиции (0-based):
    MJD = line[7:15], флаг UT1 = line[57], UT1-UTC (сек) = line[58:68].
    Примеры: '...I 0.4132375' (положительное), '...I-0.5868367' (отрицательное).
    """
    if len(line) < 68:
        return None
    try:
        mjd = float(line[7:15])
        dut1 = float(line[58:68])
    except ValueError:
        return None
    if abs(dut1) > 1.5:
        return None
    return mjd, dut1, line[57]


def rdp(points, tol):
    """Итеративный Ramer–Douglas–Peucker по вертикальному отклонению."""
    n = len(points)
    keep = [False] * n
    keep[0] = keep[n - 1] = True
    stack = [(0, n - 1)]
    while stack:
        lo, hi = stack.pop()
        if hi - lo < 2:
            continue
        x0, y0 = points[lo]
        x1, y1 = points[hi]
        worst, worst_d = -1, 0.0
        for i in range(lo + 1, hi):
            x, y = points[i]
            t = (x - x0) / (x1 - x0)
            dy = abs(y - (y0 + t * (y1 - y0)))
            if dy > worst_d:
                worst, worst_d = i, dy
        if worst_d > tol:
            keep[worst] = True
            stack.append((lo, worst))
            stack.append((worst, hi))
    return [p for p, k in zip(points, keep) if k]


def main():
    merged = {}
    # .all сначала (история), затем .daily (свежие финалы + прогноз) поверх.
    for url in URLS:
        try:
            rows = [r for r in (parse_line(l) for l in fetch(url)) if r]
        except Exception as e:  # noqa: BLE001
            print(f'  !! недоступен: {e}', file=sys.stderr)
            if url == URLS[1] and not merged:
                print('Нет данных — генерация прервана.', file=sys.stderr)
                return 1
            continue
        print(f'  {len(rows)} строк: {to_date(rows[0][0])} .. {to_date(rows[-1][0])}')
        for mjd, v, flag in rows:
            merged[mjd] = (v, flag)

    series = sorted((m, v) for m, (v, _) in merged.items() if m >= MJD_START)
    if not series:
        print('Пустая серия DUT1.', file=sys.stderr)
        return 1
    print(f'Серия с {to_date(series[0][0])} по {to_date(series[-1][0])}: {len(series)} дней')

    # Скачки високосных секунд делят серию на куски (скачок не «замазываем»).
    leap_idx = [i for i in range(1, len(series)) if series[i][1] - series[i - 1][1] > 0.5]
    bounds = [0] + leap_idx + [len(series)]
    result = []
    for a, b in zip(bounds, bounds[1:]):
        result.extend(rdp(series[a:b], TOL_S))
    dedup = []
    for m, v in result:
        if dedup and dedup[-1][0] == m and abs(dedup[-1][1] - v) < 1e-9:
            continue
        dedup.append((m, v))
    result = dedup

    # Дубли MJD для ступеньки високосной секунды.
    out = []
    for i, (m, v) in enumerate(result):
        if i > 0 and v - result[i - 1][1] > 0.5 and m == result[i - 1][0] + 1:
            out.append((m, result[i - 1][1]))
        out.append((m, v))
    print(f'После децимации (допуск {TOL_S * 1000:.0f} мс): {len(out)} точек')

    # Контроль максимальной ошибки интерполяции.
    max_err, j = 0.0, 0
    for m, v in series:
        while j < len(out) - 2 and out[j + 1][0] <= m:
            j += 1
        x0, y0 = out[j]
        x1, y1 = out[j + 1] if j + 1 < len(out) else out[j]
        est = y0 if x1 == x0 else y0 + (m - x0) / (x1 - x0) * (y1 - y0)
        max_err = max(max_err, abs(est - v))
    print(f'Максимальная ошибка интерполяции: {max_err * 1000:.2f} мс')

    lines = [
        '// Copyright (C) 2026 Atom42 and contributors',
        '// SPDX-License-Identifier: GPL-3.0-or-later',
        '',
        '// АВТОГЕНЕРИРОВАНО скриптом tool/fetch_dut1.py — НЕ РЕДАКТИРОВАТЬ ВРУЧНУЮ.',
        '// Источник данных: IERS Rapid Service/Prediction Center (USNO),',
        f'// Bulletin A: finals2000A.all + finals2000A.daily, полученные {date.today().isoformat()}.',
        f'// Покрытие: {to_date(out[0][0])} .. {to_date(out[-1][0])} (включая прогноз).',
        '// Точность линейной интерполяции: не хуже 3 мс.',
        '// Скачки високосных секунд закодированы дублями MJD:',
        '//   (MJD, значение_до), (MJD, значение_после).',
        '',
        "/// Пары `(MJD, DUT1)`: DUT1 = UT1 − UTC в секундах, MJD по UTC.",
        'const List<(double, double)> kDut1Entries = [',
    ]
    lines += [f'  ({m:.1f}, {v:.7f}),' for m, v in out]
    lines += [
        '];',
        '',
        "/// Високосные секунды: `(MJD начала действия, TAI − UTC после)`.",
        '/// MJD соответствует дате вступления в силу (полночь UTC).',
        'const List<(double, int)> kLeapSeconds = [',
    ]
    lines += [f'  ({to_mjd(d)}.0, {off}), // {d.isoformat()}' for d, off in LEAPS]
    lines += ['];']
    with open(OUT, 'w') as f:
        f.write('\n'.join(lines) + '\n')
    print(f'Записан {OUT}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
