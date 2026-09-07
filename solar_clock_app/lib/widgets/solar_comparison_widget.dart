import 'package:flutter/material.dart';
import '../models/location_point.dart';
import '../services/solar_time_service.dart';

/// Widget for comparing solar times between two locations
class SolarTimeComparisonWidget extends StatelessWidget {
  final LocationPoint location1;
  final LocationPoint location2;
  final String? label1;
  final String? label2;
  
  const SolarTimeComparisonWidget({
    Key? key,
    required this.location1,
    required this.location2,
    this.label1,
    this.label2,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final solarTimeService = SolarTimeService();
    
    final solarTime1 = solarTimeService.calculateApparentSolarTime(
      latitude: location1.latitude,
      longitude: location1.longitude,
    );
    
    final solarTime2 = solarTimeService.calculateApparentSolarTime(
      latitude: location2.latitude,
      longitude: location2.longitude,
    );
    
    final timeDifference = solarTime2.difference(solarTime1);
    final absMinutes = timeDifference.inMinutes.abs();
    final hours = (absMinutes / 60).floor();
    final minutes = absMinutes % 60;
    
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Сравнение солнечного времени',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildLocationCard(
                    context,
                    location: location1,
                    label: label1 ?? 'Точка 1',
                    solarTime: solarTime1,
                    isLeft: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildLocationCard(
                    context,
                    location: location2,
                    label: label2 ?? 'Точка 2',
                    solarTime: solarTime2,
                    isLeft: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDifferenceCard(context, hours, minutes, timeDifference.inMinutes),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLocationCard(
    BuildContext context, {
    required LocationPoint location,
    required String label,
    required DateTime solarTime,
    required bool isLeft,
  }) {
    return Card(
      color: isLeft ? Colors.blue[50] : Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _formatTime(solarTime),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isLeft ? Colors.blue[700] : Colors.orange[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Солнечное время',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDifferenceCard(
    BuildContext context,
    int hours,
    int minutes,
    int totalMinutes,
  ) {
    final isPositive = totalMinutes >= 0;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Text(
            'Разница во времени',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${isPositive ? '+' : '-'}${hours > 0 ? '$hours ч ' : ''}${minutes} мин',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green[700] : Colors.red[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isPositive 
                ? 'В точке 2 солнце позже' 
                : 'В точке 2 солнце раньше',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
