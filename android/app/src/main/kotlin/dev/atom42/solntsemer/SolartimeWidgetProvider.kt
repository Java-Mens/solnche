// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later
package dev.atom42.solntsemer

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent

/**
 * Провайдер виджета рабочего стола (ТЗ FR-24..FR-27).
 *
 * Частота обновлений — компромисс ТЗ FR-25 и §23.1: Android не
 * гарантирует секундные обновления виджета, поэтому:
 *  - время показывается без секунд (ЧЧ:ММ) и обновляется «неточным»
 *    будильником примерно раз в минуту (без SCHEDULE_EXACT_ALARM —
 *    лишние разрешения не запрашиваем, ТЗ §16.3);
 *  - пока приложение/служба уведомления живы, они дополнительно
 *    обновляют виджет точно по минуте;
 *  - updatePeriodMillis = 30 мин — страховочный запуск системой.
 */
class SolartimeWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        WidgetUpdater.updateAll(context)
        scheduleTick(context)
    }

    override fun onEnabled(context: Context) {
        scheduleTick(context)
    }

    override fun onDisabled(context: Context) {
        cancelTick(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_TICK) {
            WidgetUpdater.updateAll(context)
        }
    }

    companion object {
        private const val ACTION_TICK = "dev.atom42.solntsemer.widget.TICK"
        private const val TICK_MS = 60_000L

        private fun pending(context: Context): PendingIntent {
            val intent = Intent(context, SolartimeWidgetProvider::class.java)
                .setAction(ACTION_TICK)
            return PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }

        /** «Неточный» минутный будильник — бережёт батарею, без разрешений. */
        fun scheduleTick(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.setInexactRepeating(
                AlarmManager.RTC,
                System.currentTimeMillis() + TICK_MS,
                TICK_MS,
                pending(context),
            )
        }

        fun cancelTick(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.cancel(pending(context))
        }
    }
}
