// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later
package dev.atom42.solntsemer

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

/**
 * Отрисовка виджета рабочего стола (ТЗ FR-24..FR-27).
 *
 * Показывает истинное солнечное время (без секунд — обновления каждую
 * секунду Android не гарантирует, ТЗ FR-25), смещение от UTC, подпись
 * точки и краткие восход/заход. Данные берутся из [WidgetConfigStore],
 * время пересчитывается нативно [NativeSolarTime] — виджет живёт и без
 * запущенного приложения. Касание открывает приложение (FR-27).
 */
object WidgetUpdater {

    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, SolartimeWidgetProvider::class.java),
        )
        if (ids.isEmpty()) return
        val views = buildViews(context, WidgetConfigStore.read(context), System.currentTimeMillis())
        manager.updateAppWidget(ids, views)
    }

    fun buildViews(context: Context, data: WidgetConfigStore.Data, nowMs: Long): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.solartime_widget)

        if (!data.hasPoint) {
            views.setTextViewText(R.id.widget_time, "--:--")
            views.setTextViewText(R.id.widget_point, "Точка не выбрана")
            views.setViewVisibility(R.id.widget_offset, View.GONE)
            views.setViewVisibility(R.id.widget_sun, View.GONE)
        } else {
            val snap = NativeSolarTime.compute(
                latDeg = data.lat,
                lonDeg = data.lon,
                dut1Sec = data.dut1,
                taiMinusUtcSec = data.taiUtc,
                utcMs = nowMs,
            )
            views.setTextViewText(R.id.widget_time, NativeSolarTime.formatHm(snap.latHours))

            views.setViewVisibility(
                R.id.widget_offset,
                if (data.showOffset) View.VISIBLE else View.GONE,
            )
            if (data.showOffset) {
                views.setTextViewText(
                    R.id.widget_offset,
                    NativeSolarTime.formatOffset(snap.utcOffsetHours, withSeconds = false),
                )
            }

            val staleSuffix = when {
                data.isStaleNow && data.isDynamic -> " · устарело"
                else -> ""
            }
            views.setTextViewText(
                R.id.widget_point,
                "%.4f, %.4f%s".format(data.lat, data.lon, staleSuffix),
            )
            views.setTextViewText(R.id.widget_label, data.label)

            views.setViewVisibility(
                R.id.widget_sun,
                if (data.showSun) View.VISIBLE else View.GONE,
            )
            if (data.showSun) {
                views.setTextViewText(R.id.widget_sun, sunLine(snap))
            }
        }

        // Касание по виджету открывает приложение (ТЗ FR-27).
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launch != null) {
            val pending = PendingIntent.getActivity(
                context,
                0,
                launch,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            views.setOnClickPendingIntent(R.id.widget_root, pending)
        }
        return views
    }

    /** «↑ 07:21 · ↓ 18:32» (местное время устройства) или полярный случай. */
    private fun sunLine(snap: NativeSolarTime.Snapshot): String = when {
        snap.polarDay -> "полярный день"
        snap.polarNight -> "полярная ночь"
        else -> {
            val parts = mutableListOf<String>()
            snap.riseUtcMs?.let { parts.add("↑ ${NativeSolarTime.formatLocalHm(it)}") }
            snap.setUtcMs?.let { parts.add("↓ ${NativeSolarTime.formatLocalHm(it)}") }
            if (parts.isEmpty()) "" else parts.joinToString(" · ")
        }
    }
}
