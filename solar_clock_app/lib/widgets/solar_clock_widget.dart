import 'dart:async';
import 'package:flutter/material.dart';
import '../models/location_point.dart';
import '../services/solar_time_service.dart';
import '../services/notification_service.dart';

/// Widget for displaying solar time clock with UTC offset
/// Implements FR-01, FR-02, FR-03, FR-16, FR-21
class SolarClockWidget extends StatefulWidget {
  final LocationPoint location;
  final String? label;
  final bool showMilliseconds;
  final bool enableNotifications;
  
  const SolarClockWidget({
    Key? key,
    required this.location,
    this.label,
    this.showMilliseconds = false,
    this.enableNotifications = false,
  }) : super(key: key);
  
  @override
  State<SolarClockWidget> createState() => _SolarClockWidgetState();
}

class _SolarClockWidgetState extends State<SolarClockWidget> {
  late Timer _timer;
  late DateTime _currentSolarTime;
  late String _utcOffset;
  late String _locationName;
  
  final SolarTimeService _solarTimeService = SolarTimeService();
  final NotificationService _notificationService = NotificationService();
  bool _isNotificationVisible = false;
  
  @override
  void initState() {
    super.initState();
    _locationName = '${widget.location.latitude.toStringAsFixed(4)}, ${widget.location.longitude.toStringAsFixed(4)}';
    _updateSolarTime();
    // Update every 100ms for millisecond precision if enabled, otherwise every second
    _timer = Timer.periodic(
      Duration(milliseconds: widget.showMilliseconds ? 100 : 1000), 
      (timer) {
        _updateSolarTime();
      },
    );
  }
  
  @override
  void dispose() {
    _timer.cancel();
    if (_isNotificationVisible) {
      _notificationService.cancelSolarTimeNotification();
    }
    super.dispose();
  }
  
  void _updateSolarTime() async {
    final solarTime = _solarTimeService.calculateApparentSolarTime(
      latitude: widget.location.latitude,
      longitude: widget.location.longitude,
    );
    
    final offsetSeconds = _solarTimeService.calculateUTCOffsetSeconds(
      latitude: widget.location.latitude,
      longitude: widget.location.longitude,
    );
    final utcOffset = _solarTimeService.formatUTCOffset(offsetSeconds);
    
    setState(() {
      _currentSolarTime = solarTime;
      _utcOffset = utcOffset;
    });
    
    // Update persistent notification if enabled
    if (widget.enableNotifications && !_isNotificationVisible) {
      await _showPersistentNotification();
    } else if (widget.enableNotifications && _isNotificationVisible) {
      await _notificationService.updateSolarTimeNotification(
        solarTime: _formatTime(_currentSolarTime, includeMilliseconds: widget.showMilliseconds),
        location: _locationName,
        utcOffset: _utcOffset,
      );
    }
  }
  
  Future<void> _showPersistentNotification() async {
    try {
      await _notificationService.initialize();
      await _notificationService.requestPermissions();
      await _notificationService.showSolarTimeNotification(
        solarTime: _formatTime(_currentSolarTime, includeMilliseconds: widget.showMilliseconds),
        location: _locationName,
        utcOffset: _utcOffset,
      );
      _isNotificationVisible = true;
    } catch (e) {
      print('Error showing notification: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final sunTimes = _solarTimeService.calculateSunTimes(
      latitude: widget.location.latitude,
      longitude: widget.location.longitude,
    );
    
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.label != null)
              Text(
                widget.label!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              '${widget.location.latitude.toStringAsFixed(4)}, ${widget.location.longitude.toStringAsFixed(4)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            // Solar time display per FR-01
            Text(
              _formatTime(_currentSolarTime),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.orange[700],
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Истинное солнечное время',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            // UTC offset per FR-03
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(
                _utcOffset,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Sunrise/sunset per FR-16
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSunTimeItem(context, 'Восход', sunTimes['sunrise']),
                _buildSunTimeItem(context, 'Зенит', sunTimes['solar_noon']),
                _buildSunTimeItem(context, 'Закат', sunTimes['sunset']),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSunTimeItem(BuildContext context, String label, DateTime? time) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          time != null ? _formatTime(time) : '--:--',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
  
  String _formatTime(DateTime time, {bool includeMilliseconds = false}) {
    final baseTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
    if (includeMilliseconds) {
      return '$baseTime:${time.millisecond.toString().padLeft(3, '0')}';
    }
    return baseTime;
  }
}
