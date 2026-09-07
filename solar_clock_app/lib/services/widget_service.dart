import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

/// Service for managing Android home screen widget
class WidgetService {
  /// Initialize the home widget
  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId('group.com.solarclock.app');
  }
  
  /// Register callback for widget interactions
  static void registerCallback(Function(Uri?) callback) {
    HomeWidget.widgetClicked.listen(callback);
  }
  
  /// Update widget with solar time data
  static Future<void> updateWidget({
    required String solarTime,
    required String location,
    required String sunrise,
    required String sunset,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('solar_time', solarTime);
      await HomeWidget.saveWidgetData<String>('location', location);
      await HomeWidget.saveWidgetData<String>('sunrise', sunrise);
      await HomeWidget.saveWidgetData<String>('sunset', sunset);
      await HomeWidget.updateWidget(
        name: 'SolarClockWidgetProvider',
        androidName: 'SolarClockWidgetProvider',
      );
    } catch (e) {
      print('Error updating widget: $e');
    }
  }
  
  /// Clear widget data
  static Future<void> clearWidgetData() async {
    await HomeWidget.saveWidgetData<String>('solar_time', '--:--');
    await HomeWidget.saveWidgetData<String>('location', 'Нет данных');
    await HomeWidget.saveWidgetData<String>('sunrise', '--:--');
    await HomeWidget.saveWidgetData<String>('sunset', '--:--');
    await HomeWidget.updateWidget(
      name: 'SolarClockWidgetProvider',
      androidName: 'SolarClockWidgetProvider',
    );
  }
}
