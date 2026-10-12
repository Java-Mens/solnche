// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later
package dev.atom42.solntsemer

import android.content.Context
import android.content.SharedPreferences

/**
 * Конфигурация и данные виджета, проталкиваемые из Flutter
 * (buildWidgetPayload в widget_repository.dart).
 *
 * Хранятся в обычных SharedPreferences (не flutter.*), чтобы нативная
 * часть читала их без запущенного Flutter-движка — виджет работает,
 * даже когда приложение закрыто (ТЗ FR-25, FR-27).
 */
object WidgetConfigStore {

    private const val PREFS = "solntsemer_widget"

    private const val K_SOURCE = "source" // "a" | "b" | "fixed"
    private const val K_HAS_POINT = "has_point"
    private const val K_LAT = "lat"
    private const val K_LON = "lon"
    private const val K_LABEL = "label"
    private const val K_DUT1 = "dut1"
    private const val K_DUT1_PRECISE = "dut1_precise"
    private const val K_TAI_UTC = "tai_utc"
    private const val K_SHOW_OFFSET = "show_offset"
    private const val K_SHOW_SUN = "show_sun"
    private const val K_PUSHED_AT = "pushed_at_ms"

    /** Через сколько данные точки A/B считаются устаревшими (ТЗ FR-27). */
    private const val STALE_AFTER_MS = 15L * 60 * 1000

    data class Data(
        val source: String,
        val hasPoint: Boolean,
        val lat: Double,
        val lon: Double,
        val label: String,
        val dut1: Double,
        val dut1Precise: Boolean,
        val taiUtc: Double,
        val showOffset: Boolean,
        val showSun: Boolean,
        val pushedAtMs: Long,
    ) {
        val isDynamic: Boolean get() = source == "a" || source == "b"
        val isStaleNow: Boolean
            get() = System.currentTimeMillis() - pushedAtMs > STALE_AFTER_MS
    }

    fun read(context: Context): Data {
        val p = prefs(context)
        return Data(
            source = p.getString(K_SOURCE, "a") ?: "a",
            hasPoint = p.getBoolean(K_HAS_POINT, false),
            lat = Double.fromBits(p.getLong(K_LAT, 0.0.toRawBits())),
            lon = Double.fromBits(p.getLong(K_LON, 0.0.toRawBits())),
            label = p.getString(K_LABEL, "Точка") ?: "Точка",
            dut1 = Double.fromBits(p.getLong(K_DUT1, 0.0.toRawBits())),
            dut1Precise = p.getBoolean(K_DUT1_PRECISE, false),
            taiUtc = Double.fromBits(p.getLong(K_TAI_UTC, 37.0.toRawBits())),
            showOffset = p.getBoolean(K_SHOW_OFFSET, true),
            showSun = p.getBoolean(K_SHOW_SUN, true),
            pushedAtMs = p.getLong(K_PUSHED_AT, 0L),
        )
    }

    /** Записывает полезную нагрузку из Flutter и обновляет виджеты. */
    fun update(context: Context, payload: Map<*, *>) {
        prefs(context).edit().apply {
            putString(K_SOURCE, payload["source"] as? String ?: "a")
            putBoolean(K_HAS_POINT, payload["hasPoint"] as? Boolean ?: false)
            putLong(K_LAT, (payload["lat"] as? Double ?: 0.0).toRawBits())
            putLong(K_LON, (payload["lon"] as? Double ?: 0.0).toRawBits())
            putString(K_LABEL, payload["label"] as? String ?: "Точка")
            putLong(K_DUT1, (payload["dut1"] as? Double ?: 0.0).toRawBits())
            putBoolean(K_DUT1_PRECISE, payload["dut1Precise"] as? Boolean ?: false)
            putLong(K_TAI_UTC, (payload["taiUtc"] as? Double ?: 37.0).toRawBits())
            putBoolean(K_SHOW_OFFSET, payload["showOffset"] as? Boolean ?: true)
            putBoolean(K_SHOW_SUN, payload["showSun"] as? Boolean ?: true)
            putLong(K_PUSHED_AT, payload["pushedAtMs"] as? Long ?: 0L)
        }.apply()
        WidgetUpdater.updateAll(context)
    }

    /** Точка уведомления для fallback-расчёта службы (ТЗ FR-21). */
    fun readNotificationPoint(context: Context): Data? {
        val d = read(context)
        return if (d.hasPoint) d else null
    }

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
