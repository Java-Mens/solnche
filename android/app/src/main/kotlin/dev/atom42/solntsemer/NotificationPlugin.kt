// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later
package dev.atom42.solntsemer

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * MethodChannel постоянного уведомления (ТЗ FR-20..FR-23):
 * isPermitted / requestPermission / start / update / stop.
 */
class NotificationPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    ActivityAware, PluginRegistry.RequestPermissionsResultListener {

    companion object {
        private const val CHANNEL = "dev.atom42.solntsemer/notification"
        private const val PERMISSION_REQUEST_CODE = 1002
    }

    private var context: Context? = null
    private var activity: Activity? = null
    private var channel: MethodChannel? = null
    private var pendingResult: MethodChannel.Result? = null

    // ── FlutterPlugin ──────────────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
            .also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    // ── ActivityAware ──────────────────────────────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // ── Разрешение POST_NOTIFICATIONS (ТЗ FR-23) ───────────────────────────

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingResult?.success(granted)
        pendingResult = null
        return true
    }

    // ── Методы канала ──────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = this.context ?: run {
            result.error("no_context", "нет контекста", null)
            return
        }
        when (call.method) {
            "isPermitted" -> {
                result.success(NotificationManagerCompat.from(context).areNotificationsEnabled())
            }

            "requestPermission" -> {
                if (Build.VERSION.SDK_INT < 33) {
                    // Разрешение нужно только с Android 13 — считаем выданным.
                    result.success(true)
                    return
                }
                val granted = ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.POST_NOTIFICATIONS,
                ) == PackageManager.PERMISSION_GRANTED
                if (granted) {
                    result.success(true)
                    return
                }
                val activity = this.activity
                if (activity == null) {
                    result.success(false)
                    return
                }
                // Результат придёт в onRequestPermissionsResult.
                pendingResult?.success(false)
                pendingResult = result
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    PERMISSION_REQUEST_CODE,
                )
            }

            "start" -> {
                val title = call.argument<String>("title") ?: "Истинное время"
                val text = call.argument<String>("text") ?: ""
                SolarTimeService.start(context, title, text)
                result.success(null)
            }

            "update" -> {
                val title = call.argument<String>("title") ?: return result.success(null)
                val text = call.argument<String>("text") ?: ""
                SolarTimeService.pushUpdate(context, title, text)
                result.success(null)
            }

            "stop" -> {
                SolarTimeService.stop(context)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }
}
