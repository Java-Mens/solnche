// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later
package dev.atom42.solntsemer

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.asin
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.sin

/**
 * Упрощённый калькулятор истинного солнечного времени (LAT) для нативных
 * частей: виджета рабочего стола и fallback-тика уведомления, когда
 * Flutter-движок не запущен (ТЗ FR-21, FR-25, FR-27).
 *
 * Алгоритм — «Meeus, Astronomical Algorithms» в упрощении:
 *  - солнечные координаты низкой точности (гл. 25): точность ~0.01°,
 *    что даёт ~2–3 с во времени;
 *  - гринвичское среднее звёздное время (гл. 12.4) + главные члены нутации
 *    по долготе (гл. 22, низкая точность);
 *  - LAT = (GAST + λ − α_app)/15 + 12h — та же формула, что и в Flutter-части
 *    (ТЗ §12.1), DUT1 и високосные секунды передаются из Dart.
 *
 * Восход/заход/полдень ищутся сканированием высоты Солнца с шагом 10 минут
 * и бисекцией до ~1 с — достаточно для минутной точности виджета (FR-19/25).
 */
object NativeSolarTime {

    /** Высота центра Солнца на восходе/заходе: наблюдаемый режим (ТЗ FR-18). */
    private const val H0_DEG = -0.833

    data class Snapshot(
        /** Истинное солнечное время, часы [0, 24). */
        val latHours: Double,
        /** Смещение LAT − UTC, часы в (−12, +12]. */
        val utcOffsetHours: Double,
        /** Ближайший восход (UTC, unix ms) или null (полярная ночь/день). */
        val riseUtcMs: Long?,
        /** Ближайший заход (UTC, unix ms) или null. */
        val setUtcMs: Long?,
        /** Ближайший полдень (UTC, unix ms). */
        val noonUtcMs: Long?,
        val polarDay: Boolean,
        val polarNight: Boolean,
    )

    /** Положение Солнца: прямое восхождение и склонение (градусы). */
    private data class SunPos(val raDeg: Double, val decDeg: Double)

    fun compute(
        latDeg: Double,
        lonDeg: Double,
        dut1Sec: Double,
        taiMinusUtcSec: Double,
        utcMs: Long,
    ): Snapshot {
        val deltaTSec = 32.184 + taiMinusUtcSec - dut1Sec
        val jdUt1 = jdFromUtcMs(utcMs) + dut1Sec / 86400.0
        val jde = jdUt1 + deltaTSec / 86400.0

        val sun = sunPosition(jde)
        val gast = gastDeg(jdUt1, jde)

        // Часовой угол: H = LST − RA, солнечный полдень при H = 0.
        val lst = norm360(gast + lonDeg)
        val haDeg = norm180(lst - sun.raDeg)
        val latHours = mod((haDeg / 15.0) + 12.0, 24.0)

        val utcHours = ((utcMs % 86400000L) + 86400000L) % 86400000L / 3600000.0
        val utcOffsetHours = normHalfDay(latHours - utcHours)

        // Восход/заход/полдень — сканированием следующих 48 часов.
        val events = scanEvents(latDeg, lonDeg, dut1Sec, taiMinusUtcSec, utcMs)

        return Snapshot(
            latHours = latHours,
            utcOffsetHours = utcOffsetHours,
            riseUtcMs = events?.riseUtcMs,
            setUtcMs = events?.setUtcMs,
            noonUtcMs = events?.noonUtcMs,
            polarDay = events == null && altitudeDeg(latDeg, lonDeg, dut1Sec, taiMinusUtcSec, utcMs) > 0,
            polarNight = events == null && altitudeDeg(latDeg, lonDeg, dut1Sec, taiMinusUtcSec, utcMs) <= 0,
        )
    }

    // ── Астрономия ────────────────────────────────────────────────────────

    private fun jdFromUtcMs(utcMs: Long): Double = 2440587.5 + utcMs / 86400000.0

    /** Видимое прямое восхождение и склонение Солнца (градусы), Meeus гл. 25. */
    private fun sunPosition(jde: Double): SunPos {
        val t = (jde - 2451545.0) / 36525.0
        val l0 = norm360(280.46646 + 36000.76983 * t + 0.0003032 * t * t)
        val m = norm360(357.52911 + 35999.05029 * t - 0.0001537 * t * t)
        val e = 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t
        val c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * sinD(m) +
            (0.019993 - 0.000101 * t) * sinD(2 * m) +
            0.000289 * sinD(3 * m)
        val trueLon = l0 + c
        val omega = norm360(125.04 - 1934.136 * t)
        // Аберрация + нутация по долготе для видимого места:
        val appLon = trueLon - 0.00569 - 0.00478 * sinD(omega)
        val eps = 23.439291111 - 0.0130041667 * t - 1.638889e-7 * t * t

        val raDeg = atan2(cosD(eps) * sinD(appLon), cosD(appLon)) * RAD2DEG
        val decDeg = asin(sinD(eps) * sinD(appLon)) * RAD2DEG
        return SunPos(norm360(raDeg), decDeg)
    }

    /** Истинное гринвичское звёздное время (градусы): GMST + Δψ·cos ε. */
    private fun gastDeg(jdUt1: Double, jde: Double): Double {
        val tu = (jdUt1 - 2451545.0) / 36525.0
        val gmst = 280.46061837 +
            360.98564736629 * (jdUt1 - 2451545.0) +
            0.000387933 * tu -
            tu * tu * tu / 38710000.0
        val t = (jde - 2451545.0) / 36525.0
        val omega = norm360(125.04 - 1934.136 * t)
        val l0 = norm360(280.46646 + 36000.76983 * t)
        val m = norm360(357.52911 + 35999.05029 * t)
        // Нутация по долготе, главные члены (Meeus гл. 22, низкая точность).
        val dPsi = (-17.20 * sinD(omega) - 1.32 * sinD(2 * l0) -
            0.23 * sinD(2 * omega) + 0.21 * sinD(2 * m)) / 3600.0
        val eps = 23.439291111 - 0.0130041667 * t
        return norm360(gmst + dPsi * cosD(eps))
    }

    /** Высота центра Солнца над горизонтом (градусы). */
    fun altitudeDeg(
        latDeg: Double,
        lonDeg: Double,
        dut1Sec: Double,
        taiMinusUtcSec: Double,
        utcMs: Long,
    ): Double {
        val deltaTSec = 32.184 + taiMinusUtcSec - dut1Sec
        val jdUt1 = jdFromUtcMs(utcMs) + dut1Sec / 86400.0
        val jde = jdUt1 + deltaTSec / 86400.0
        val sun = sunPosition(jde)
        val gast = gastDeg(jdUt1, jde)
        val lst = norm360(gast + lonDeg)
        val haRad = norm180(lst - sun.raDeg) * DEG2RAD
        val latRad = latDeg * DEG2RAD
        val decRad = sun.decDeg * DEG2RAD
        val sinH = sin(latRad) * sin(decRad) + cos(latRad) * cos(decRad) * cos(haRad)
        return asin(sinH.coerceIn(-1.0, 1.0)) * RAD2DEG
    }

    // ── События (восход/заход/полдень) ────────────────────────────────────

    private data class Events(val riseUtcMs: Long?, val setUtcMs: Long?, val noonUtcMs: Long?)

    /**
     * Ищет ближайшие переходы высоты через h0 и ближайший полдень
     * в интервале [utcMs, utcMs + 48ч]. null — переходов нет (полярный случай).
     */
    private fun scanEvents(
        latDeg: Double,
        lonDeg: Double,
        dut1Sec: Double,
        taiMinusUtcSec: Double,
        utcMs: Long,
    ): Events? {
        val stepMs = 10L * 60 * 1000 // 10 минут
        val horizonMs = utcMs + 48L * 3600 * 1000
        var riseMs: Long? = null
        var setMs: Long? = null
        var noonMs: Long? = null

        var tPrev = utcMs
        var altPrev = altitudeDeg(latDeg, lonDeg, dut1Sec, taiMinusUtcSec, tPrev) - H0_DEG
        // Полдень: часовой угол, переход через 0 (отрицательный → положительный).
        var haPrev = hourAngleDeg(lonDeg, dut1Sec, taiMinusUtcSec, tPrev)

        while (tPrev < horizonMs && (riseMs == null || setMs == null || noonMs == null)) {
            val t = tPrev + stepMs
            val alt = altitudeDeg(latDeg, lonDeg, dut1Sec, taiMinusUtcSec, t) - H0_DEG
            val ha = hourAngleDeg(lonDeg, dut1Sec, taiMinusUtcSec, t)

            if (riseMs == null && altPrev < 0 && alt >= 0) {
                riseMs = bisect(latDeg, lonDeg, dut1Sec, taiMinusUtcSec, tPrev, t, rising = true)
            }
            if (setMs == null && altPrev >= 0 && alt < 0) {
                setMs = bisect(latDeg, lonDeg, dut1Sec, taiMinusUtcSec, tPrev, t, rising = false)
            }
            if (noonMs == null && haPrev < 0 && ha >= 0) {
                noonMs = bisectNoon(lonDeg, dut1Sec, taiMinusUtcSec, tPrev, t)
            }

            tPrev = t
            altPrev = alt
            haPrev = ha
        }

        if (riseMs == null && setMs == null && noonMs == null) return null
        return Events(riseMs, setMs, noonMs)
    }

    private fun hourAngleDeg(lonDeg: Double, dut1Sec: Double, taiMinusUtcSec: Double, utcMs: Long): Double {
        val jdUt1 = jdFromUtcMs(utcMs) + dut1Sec / 86400.0
        val jde = jdUt1 + (32.184 + taiMinusUtcSec - dut1Sec) / 86400.0
        val sun = sunPosition(jde)
        val gast = gastDeg(jdUt1, jde)
        return norm180(norm360(gast + lonDeg) - sun.raDeg)
    }

    /** Бисекция перехода высоты через h0, точность ~1 с. */
    private fun bisect(
        latDeg: Double, lonDeg: Double, dut1Sec: Double, taiMinusUtcSec: Double,
        loMs: Long, hiMs: Long, rising: Boolean,
    ): Long {
        var lo = loMs
        var hi = hiMs
        repeat(12) {
            val mid = (lo + hi) / 2
            val f = altitudeDeg(latDeg, lonDeg, dut1Sec, taiMinusUtcSec, mid) - H0_DEG
            if (rising) {
                if (f < 0) lo = mid else hi = mid
            } else {
                if (f >= 0) lo = mid else hi = mid
            }
        }
        return (lo + hi) / 2
    }

    /** Бисекция перехода часового угла через 0 (полдень). */
    private fun bisectNoon(lonDeg: Double, dut1Sec: Double, taiMinusUtcSec: Double, loMs: Long, hiMs: Long): Long {
        var lo = loMs
        var hi = hiMs
        repeat(12) {
            val mid = (lo + hi) / 2
            if (hourAngleDeg(lonDeg, dut1Sec, taiMinusUtcSec, mid) < 0) lo = mid else hi = mid
        }
        return (lo + hi) / 2
    }

    // ── Форматирование ────────────────────────────────────────────────────

    /** «ЧЧ:ММ» из часов [0, 24). */
    fun formatHm(hours: Double): String {
        val h = mod(hours, 24.0)
        val totalSec = (h * 3600).round()
        val hh = (totalSec / 3600) % 24
        val mm = (totalSec % 3600) / 60
        return "%02d:%02d".format(hh.toInt(), mm.toInt())
    }

    /** «ЧЧ:ММ:СС» из часов [0, 24). */
    fun formatHms(hours: Double): String {
        val h = mod(hours, 24.0)
        val totalSec = (h * 3600).round()
        val hh = (totalSec / 3600) % 24
        val mm = (totalSec % 3600) / 60
        val ss = totalSec % 60
        return "%02d:%02d:%02d".format(hh.toInt(), mm.toInt(), ss.toInt())
    }

    /** «UTC+ЧЧ:ММ:СС» из часов (−12, 12]. */
    fun formatOffset(hours: Double, withSeconds: Boolean = true): String {
        val h = normHalfDay(hours)
        val sign = if (h < 0) "−" else "+"
        val absSec = abs(h * 3600).round()
        val hh = absSec / 3600
        val mm = (absSec % 3600) / 60
        val ss = absSec % 60
        return if (withSeconds) {
            "UTC%s%02d:%02d:%02d".format(sign, hh.toInt(), mm.toInt(), ss.toInt())
        } else {
            "UTC%s%02d:%02d".format(sign, hh.toInt(), mm.toInt())
        }
    }

    /** «ЧЧ:ММ» момента UTC в местном времени устройства. */
    fun formatLocalHm(utcMs: Long): String {
        val offsetMs = java.util.TimeZone.getDefault().getOffset(utcMs).toLong()
        val localMs = utcMs + offsetMs
        val h = ((localMs % 86400000L) + 86400000L) % 86400000L / 3600000.0
        return formatHm(h)
    }

    // ── Математика ────────────────────────────────────────────────────────

    private const val DEG2RAD = PI / 180.0
    private const val RAD2DEG = 180.0 / PI

    private fun sinD(deg: Double) = sin(deg * DEG2RAD)
    private fun cosD(deg: Double) = cos(deg * DEG2RAD)

    private fun norm360(deg: Double): Double {
        var d = deg % 360.0
        if (d < 0) d += 360.0
        return d
    }

    /** Нормализация в (−180, 180]. */
    private fun norm180(deg: Double): Double {
        var d = norm360(deg)
        if (d > 180.0) d -= 360.0
        return d
    }

    /** Нормализация в (−12, +12]. */
    private fun normHalfDay(hours: Double): Double {
        var h = mod(hours, 24.0)
        if (h > 12.0) h -= 24.0
        return h
    }

    private fun mod(a: Double, n: Double): Double {
        val r = a - n * floor(a / n)
        return if (r < 0) r + n else r
    }

    private fun Double.round(): Long = Math.round(this)
}
