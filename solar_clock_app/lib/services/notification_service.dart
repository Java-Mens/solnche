import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// Service for managing local notifications
/// Implements FR-20, FR-21, FR-22, FR-23
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  
  factory NotificationService() {
    return _instance;
  }
  
  NotificationService._internal();
  
  /// Get singleton instance
  static NotificationService get instance => _instance;
  
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  
  /// Channel IDs for different notification types
  static const String _solarTimeChannelId = 'solar_time_channel';
  static const String _solarNoonChannelId = 'solar_noon_channel';
  static const String _sunriseSunsetChannelId = 'sunrise_sunset_channel';
  
  /// Initialize notification service with timezone support
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize timezone database
    tz.initializeTimeZones();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: false,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open Solar Clock',
    );
    
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      linux: linuxSettings,
    );
    
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTapped,
    );
    
    // Create notification channels
    await _createNotificationChannels();
    _isInitialized = true;
  }
  
  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      // Solar time updates channel (low priority, ongoing)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _solarTimeChannelId,
          'Солнечное время',
          description: 'Постоянное уведомление с текущим солнечным временем',
          importance: Importance.low,
          showBadge: false,
          enableVibration: false,
          playSound: false,
        ),
      );
      
      // Solar noon events channel (default priority)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _solarNoonChannelId,
          'Солнечный зенит',
          description: 'Ежедневное уведомление о солнечном полдне',
          importance: Importance.defaultImportance,
          showBadge: true,
          enableVibration: true,
        ),
      );
      
      // Sunrise/sunset events channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _sunriseSunsetChannelId,
          'Восход и закат',
          description: 'Уведомления о восходе и закате солнца',
          importance: Importance.defaultImportance,
          showBadge: true,
          enableVibration: false,
        ),
      );
    }
  }
  
  /// Handle notification tap in foreground
  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // Can navigate to specific screen based on payload
  }
  
  /// Handle notification tap from background/terminated state
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    print('Background notification tapped: ${response.payload}');
  }
  
  /// Request notification permissions (Android 13+)
  Future<bool> requestPermissions() async {
    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImpl != null) {
      final granted = await androidImpl.requestNotificationsPermission();
      if (granted == null || !granted) {
        return false;
      }
    }
    
    final iosImpl = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    
    if (iosImpl != null) {
      final granted = await iosImpl.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    
    return true;
  }
  
  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImpl != null) {
      final enabled = await androidImpl.areNotificationsEnabled();
      return enabled ?? false;
    }
    
    return true;
  }
  
  /// Show a persistent notification with solar time info (FR-21)
  /// Used for foreground service to keep app alive
  Future<void> showSolarTimeNotification({
    required String solarTime,
    required String location,
    required String utcOffset,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    final androidDetails = AndroidNotificationDetails(
      _solarTimeChannelId,
      'Солнечное время',
      channelDescription: 'Постоянное уведомление с текущим солнечным временем',
      importance: Importance.low,
      icon: '@mipmap/ic_launcher',
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      category: AndroidNotificationCategory.service,
      visibility: NotificationVisibility.public,
      styleInformation: const BigTextStyleInformation(
        '',
        contentTitle: 'Солнечное время',
        summaryText: 'Обновляется каждую секунду',
      ),
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
      interruptionLevel: InterruptionLevel.passive,
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.show(
      0,
      '☀️ $solarTime ($utcOffset)',
      '📍 $location',
      details,
      payload: 'solar_time_update',
    );
  }
  
  /// Update existing solar time notification
  Future<void> updateSolarTimeNotification({
    required String solarTime,
    required String location,
    required String utcOffset,
  }) async {
    await showSolarTimeNotification(
      solarTime: solarTime,
      location: location,
      utcOffset: utcOffset,
    );
  }
  
  /// Cancel solar time notification
  Future<void> cancelSolarTimeNotification() async {
    await _notifications.cancel(0);
  }
  
  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
  
  /// Schedule daily solar noon notification (FR-22)
  Future<void> scheduleSolarNoonNotification({
    required int hour,
    required int minute,
    bool enableVibration = true,
    bool enableSound = true,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    final androidDetails = AndroidNotificationDetails(
      _solarNoonChannelId,
      'Солнечный зенит',
      channelDescription: 'Ежедневное уведомление о солнечном полдне',
      importance: Importance.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: enableVibration,
      playSound: enableSound,
      visibility: NotificationVisibility.public,
    );
    
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: enableSound,
      interruptionLevel: InterruptionLevel.active,
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    // Schedule for next occurrence of specified time
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    await _notifications.zonedSchedule(
      1,
      '☀️ Солнечный зенит',
      'Сейчас солнечный полдень в вашей локации! Время: $hour:${minute.toString().padLeft(2, '0')}',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
  
  /// Schedule sunrise notification (FR-23)
  Future<void> scheduleSunriseNotification({
    required DateTime sunriseTime,
    bool enableVibration = false,
    bool enableSound = true,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    final tzDate = tz.TZDateTime.from(sunriseTime, tz.local);
    
    final androidDetails = AndroidNotificationDetails(
      _sunriseSunsetChannelId,
      'Восход и закат',
      channelDescription: 'Уведомления о восходе и закате солнца',
      importance: Importance.defaultImportance,
      icon: '@mipmap/ic_launcher',
      enableVibration: enableVibration,
      playSound: enableSound,
    );
    
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: enableSound,
      interruptionLevel: InterruptionLevel.passive,
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.zonedSchedule(
      2,
      '🌅 Восход солнца',
      'Солнце взошло! Хорошего дня!',
      tzDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
  
  /// Schedule sunset notification (FR-23)
  Future<void> scheduleSunsetNotification({
    required DateTime sunsetTime,
    bool enableVibration = false,
    bool enableSound = true,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    final tzDate = tz.TZDateTime.from(sunsetTime, tz.local);
    
    final androidDetails = AndroidNotificationDetails(
      _sunriseSunsetChannelId,
      'Восход и закат',
      channelDescription: 'Уведомления о восходе и закате солнца',
      importance: Importance.defaultImportance,
      icon: '@mipmap/ic_launcher',
      enableVibration: enableVibration,
      playSound: enableSound,
    );
    
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: enableSound,
      interruptionLevel: InterruptionLevel.passive,
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.zonedSchedule(
      3,
      '🌇 Закат солнца',
      'Солнце село! Доброго вечера!',
      tzDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
  
  /// Cancel all scheduled notifications
  Future<void> cancelAllScheduledNotifications() async {
    await _notifications.cancelAll();
  }
  
  /// Get pending notifications count
  Future<int> getPendingNotificationsCount() async {
    final pending = await _notifications.pendingNotificationRequests();
    return pending.length;
  }

  /// Schedule all notifications based on settings (FR-20, FR-22, FR-23)
  /// Called from settings screen when notifications are enabled
  Future<void> scheduleAllNotifications({
    double? latitude,
    double? longitude,
    required bool notifySunrise,
    required bool notifySunset,
    required bool notifySolarNoon,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Cancel all existing notifications first
    await cancelAllScheduledNotifications();

    // Schedule solar noon notification if enabled
    if (notifySolarNoon) {
      // Default solar noon time (can be calculated based on location)
      await scheduleSolarNoonNotification(
        hour: 12,
        minute: 0,
        enableVibration: true,
        enableSound: true,
      );
    }

    // Sunrise and sunset notifications require location
    if ((notifySunrise || notifySunset) && latitude != null && longitude != null) {
      // For now, we'll schedule placeholder notifications
      // In a real app, you would calculate actual sunrise/sunset times
      // based on the location and date
      print('Sunrise/sunset notifications require actual calculation based on location');
    }
  }
}
