package com.solarclock.solar_clock_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import es.antonborri.home_widget.HomeWidgetPlugin

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Регистрация плагина HomeWidget для виджета Android
        flutterEngine.plugins.add(HomeWidgetPlugin())
    }
}
