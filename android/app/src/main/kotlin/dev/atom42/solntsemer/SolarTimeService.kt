// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later
package dev.atom42.solntsemer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/**
 * Постоянное уведомление с истинным солнечным временем (ТЗ FR-20..FR-23).
 *
 * Пока живёт Flutter-движок, Dart проталкивает готовые строки каждую
 * секунду (точно те же числа, что на экране) — [pushUpdate]. Если пуши
 * прекратились (приложение убито), служба продолжает тикать сама:
 * пересчитывает время нативно по последней известной точке
 * ([NativeSolarTime], точность ~±3 с) — ТЗ FR-21.
 *
 * Низкоприоритетный канал без звука и вибрации (ТЗ FR-21).
 */
class SolarTimeService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private var lastTickAt = 0L

    private val tickRunnable = object : Runnable {
        override fun run() {
            try {
                val now = System.currentTimeMillis()
                if (now - lastPushAt > PUSH_STALE_AFTER_MS) {
                    // Flutter молчит — пересчитываем сами (fallback, ТЗ FR-21).
                    nativeNotify(now)
                }
                // Заодно освежаем виджет раз в минуту точно по минуте —
                // точнее «неточного» будильника (ТЗ FR-25).
                if ((now / 60_000L) != (lastTickAt / 60_000L)) {
                    WidgetUpdater.updateAll(applicationContext)
                }
                lastTickAt = now
            } finally {
                handler.postDelayed(this, 1000L)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel(this)
        handler.postDelayed(tickRunnable, 1000L)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: lastTitle ?: initialTitle()
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: lastText ?: ""
        startForegroundWith(title, text)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(tickRunnable)
        super.onDestroy()
    }

    private fun initialTitle(): String = "Истинное время"

    private fun startForegroundWith(title: String, text: String) {
        val notification = buildNotification(this, title, text)
        val type = if (Build.VERSION.SDK_INT >= 34) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        } else {
            0
        }
        ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, type)
    }

    /** Пересчёт строк нативно и показ уведомления (fallback-режим). */
    private fun nativeNotify(nowMs: Long) {
        val data = WidgetConfigStore.readNotificationPoint(this) ?: run {
            notifyShown(this, "Истинное время", "Точка не выбрана — откройте приложение")
            return
        }
        val snap = NativeSolarTime.compute(
            latDeg = data.lat,
            lonDeg = data.lon,
            dut1Sec = data.dut1,
            taiMinusUtcSec = data.taiUtc,
            utcMs = nowMs,
        )
        val title = "Истинное время: ${NativeSolarTime.formatHms(snap.latHours)}"
        val text = "Смещение: ${NativeSolarTime.formatOffset(snap.utcOffsetHours)} · " +
            "%.4f, %.4f".format(data.lat, data.lon)
        notifyShown(this, title, text)
    }

    companion object {
        private const val CHANNEL_ID = "solntsemer_time"
        private const val NOTIFICATION_ID = 42
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"

        /** Если Dart не обновлял строки 3 с — переходим на свой расчёт. */
        private const val PUSH_STALE_AFTER_MS = 3000L

        @Volatile var lastPushAt: Long = 0L
            private set
        @Volatile var lastTitle: String? = null
            private set
        @Volatile var lastText: String? = null
            private set

        /** Запуск службы (foreground, ТЗ §16.3) с первыми строками. */
        fun start(context: Context, title: String, text: String) {
            lastPushAt = System.currentTimeMillis()
            lastTitle = title
            lastText = text
            val intent = Intent(context, SolarTimeService::class.java)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_TEXT, text)
            try {
                androidx.core.content.ContextCompat.startForegroundService(context, intent)
            } catch (_: Exception) {
                // Например, приложение в фоне на старых Android —
                // не смертельно: приложение продолжает работать (ТЗ §20.8).
            }
        }

        /** Ежесекундный пуш строк из Flutter. */
        fun pushUpdate(context: Context, title: String, text: String) {
            lastPushAt = System.currentTimeMillis()
            lastTitle = title
            lastText = text
            notifyShown(context, title, text)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, SolarTimeService::class.java))
        }

        private fun notifyShown(context: Context, title: String, text: String) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIFICATION_ID, buildNotification(context, title, text))
        }

        private fun buildNotification(context: Context, title: String, text: String): Notification {
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            var contentIntent: PendingIntent? = null
            if (launch != null) {
                contentIntent = PendingIntent.getActivity(
                    context,
                    1,
                    launch,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                )
            }
            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setContentTitle(title)
                .setContentText(text)
                .setStyle(NotificationCompat.BigTextStyle().bigText(text))
                .setOngoing(true)
                .setSilent(true)
                .setOnlyAlertOnce(true)
                .setShowWhen(false)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setContentIntent(contentIntent)
                .build()
        }

        private fun createChannel(context: Context) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.notification_channel_name),
                NotificationManager.IMPORTANCE_LOW, // без звука (ТЗ FR-21)
            ).apply {
                description = context.getString(R.string.notification_channel_desc)
                setShowBadge(false)
            }
            nm.createNotificationChannel(channel)
        }
    }
}
