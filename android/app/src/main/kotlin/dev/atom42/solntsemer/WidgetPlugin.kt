// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later
package dev.atom42.solntsemer

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel виджета рабочего стола (ТЗ FR-24..FR-27): метод `update`
 * принимает полезную нагрузку из Flutter (точка, DUT1, флаги отображения),
 * сохраняет её в [WidgetConfigStore] и немедленно перерисовывает виджеты.
 */
class WidgetPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL = "dev.atom42.solntsemer/widget"
    }

    private var context: Context? = null
    private var channel: MethodChannel? = null

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

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = this.context ?: run {
            result.error("no_context", "нет контекста", null)
            return
        }
        when (call.method) {
            "update" -> {
                @Suppress("UNCHECKED_CAST")
                val payload = call.arguments<Map<String, Any?>>() ?: emptyMap<String, Any?>()
                WidgetConfigStore.update(context, payload)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }
}
