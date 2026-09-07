import 'package:flutter/material.dart';
import '../models/location_point.dart';
import '../services/solar_time_service.dart';

/// Widget for comparing solar times between two locations
/// Implements FR-13, FR-14, FR-15
class SolarTimeComparisonWidget extends StatefulWidget {
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
  State<SolarTimeComparisonWidget> createState() => _SolarTimeComparisonWidgetState();
}

class _SolarTimeComparisonWidgetState extends State<SolarTimeComparisonWidget> {
  late Timer _timer;
  late DateTime _solarTime1;
  late DateTime _solarTime2;
  late String _utcOffset1;
  late String _utcOffset2;
  
  final SolarTimeService _solarTimeService = SolarTimeService();
  
  @override
  void initState() {
    super.initState();
    _updateTimes();
    // Update every second per FR-02
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimes();
    });
  }
  
  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
  
  void _updateTimes() {
    setState(() {
      _solarTime1 = _solarTimeService.calculateApparentSolarTime(
        latitude: widget.location1.latitude,
        longitude: widget.location1.longitude,
      );
      
      _solarTime2 = _solarTimeService.calculateApparentSolarTime(
        latitude: widget.location2.latitude,
        longitude: widget.location2.longitude,
      );
      
      final offset1Seconds = _solarTimeService.calculateUTCOffsetSeconds(
        latitude: widget.location1.latitude,
        longitude: widget.location1.longitude,
      );
      _utcOffset1 = _solarTimeService.formatUTCOffset(offset1Seconds);
      
      final offset2Seconds = _solarTimeService.calculateUTCOffsetSeconds(
        latitude: widget.location2.latitude,
        longitude: widget.location2.longitude,
      );
      _utcOffset2 = _solarTimeService.formatUTCOffset(offset2Seconds);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final timeDifference = _solarTime2.difference(_solarTime1);
    final absMinutes = timeDifference.inMinutes.abs();
    final hours = (absMinutes / 60).floor();
    final minutes = absMinutes % 60;
    final seconds = timeDifference.inSeconds.abs() % 60;
    
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
                    location: widget.location1,
                    label: widget.label1 ?? 'Точка 1',
                    solarTime: _solarTime1,
                    utcOffset: _utcOffset1,
                    isLeft: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildLocationCard(
                    context,
                    location: widget.location2,
                    label: widget.label2 ?? 'Точка 2',
                    solarTime: _solarTime2,
                    utcOffset: _utcOffset2,
                    isLeft: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDifferenceCard(context, hours, minutes, seconds, timeDifference.inMinutes),
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
    required String utcOffset,
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
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Солнечное время',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isLeft ? Colors.blue[100] : Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                utcOffset,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isLeft ? Colors.blue[700] : Colors.orange[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
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
    int seconds,
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
            '${isPositive ? '+' : '-'}${hours > 0 ? '$hours ч ' : ''}${minutes} мин ${seconds} сек',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green[700] : Colors.red[700],
              fontFeatures: const [FontFeature.tabularFigures()],
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
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
