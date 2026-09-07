import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service for managing local notifications
class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  
  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(settings);
    _isInitialized = true;
  }
  
  /// Request notification permissions
  Future<bool> requestPermissions() async {
    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImpl != null) {
      final granted = await androidImpl.requestNotificationsPermission();
      return granted ?? false;
    }
    
    return true;
  }
  
  /// Show a notification with solar time info
  Future<void> showSolarTimeNotification({
    required String solarTime,
    required String location,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    const androidDetails = AndroidNotificationDetails(
      'solar_time_channel',
      'Солнечное время',
      channelDescription: 'Уведомления о солнечном времени',
      importance: Importance.low,
      priority: Priority.low,
      icon: '@mipmap/ic_launcher',
      ongoing: true,
      autoCancel: false,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.show(
      0,
      'Солнечное время: $solarTime',
      'Местоположение: $location',
      details,
    );
  }
  
  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
  
  /// Show daily solar noon notification
  Future<void> scheduleSolarNoonNotification({
    required int hour,
    required int minute,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    const androidDetails = AndroidNotificationDetails(
      'solar_noon_channel',
      'Солнечный зенит',
      channelDescription: 'Ежедневное уведомление о солнечном зените',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.zonedSchedule(
      1,
      'Солнечный зенит',
      'Сейчас солнечный полдень в вашей локации',
      _nextInstanceOfTime(hour, minute),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
  
  DateTime _nextInstanceOfTime(int hour, int minute) {
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
