package com.solarclock.solar_clock_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Android Home Widget Provider for Solar Clock App
 */
class SolarClockWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: RemoteViews
    ) {
        appWidgetIds.forEach { widgetId ->
            // Get saved data from SharedPreferences
            val prefs = context.getSharedPreferences(
                HomeWidgetPreferences.PREFERENCES_NAME,
                Context.MODE_PRIVATE
            )
            
            val solarTime = prefs.getString("solar_time", "--:--") ?: "--:--"
            val location = prefs.getString("location", "Нет данных") ?: "Нет данных"
            val sunrise = prefs.getString("sunrise", "--:--") ?: "--:--"
            val sunset = prefs.getString("sunset", "--:--") ?: "--:--"
            
            // Update widget views
            widgetData.setTextViewText(R.id.solar_time, solarTime)
            widgetData.setTextViewText(R.id.location, location)
            widgetData.setTextViewText(R.id.sunrise, sunrise)
            widgetData.setTextViewText(R.id.sunset, sunset)
            
            // Set up click listener to open app
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java
            )
            widgetData.setOnClickPendingIntent(R.id.solar_time, pendingIntent)
            
            appWidgetManager.updateAppWidget(widgetId, widgetData)
        }
    }
}
