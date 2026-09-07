import 'package:flutter/material.dart';
import '../models/location_point.dart';
import '../services/solar_time_service.dart';

/// Widget for displaying solar time clock
class SolarClockWidget extends StatelessWidget {
  final LocationPoint location;
  final String? label;
  
  const SolarClockWidget({
    Key? key,
    required this.location,
    this.label,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final solarTimeService = SolarTimeService();
    final apparentSolarTime = solarTimeService.calculateApparentSolarTime(
      latitude: location.latitude,
      longitude: location.longitude,
    );
    
    final sunTimes = solarTimeService.calculateSunTimes(
      latitude: location.latitude,
      longitude: location.longitude,
    );
    
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != null)
              Text(
                label!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              _formatTime(apparentSolarTime),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Истинное солнечное время',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSunTimeItem(context, 'Восход', sunTimes['sunrise']!),
                _buildSunTimeItem(context, 'Зенит', sunTimes['solar_noon']!),
                _buildSunTimeItem(context, 'Закат', sunTimes['sunset']!),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSunTimeItem(BuildContext context, String label, DateTime time) {
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
          _formatTime(time),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
