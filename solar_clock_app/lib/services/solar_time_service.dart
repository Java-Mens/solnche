import 'dart:math' as math;
import 'package:sun_calc/sun_calc.dart';

/// Service for calculating solar time based on location and date/time
class SolarTimeService {
  /// Calculate the equation of time for a given date
  /// Returns the difference in minutes between mean solar time and apparent solar time
  double calculateEquationOfTime(DateTime date) {
    final julianDate = _toJulianDate(date);
    final n = julianDate - 2451545.0;
    final L = (280.466 + 0.9856474 * n) % 360;
    final g = (357.528 + 0.9856003 * n) % 360;
    final gRad = g * (math.pi / 180.0);
    final LRad = L * (math.pi / 180.0);
    
    double eot = -1.9148 * math.sin(gRad) * math.cos(gRad / 2) - 
                 0.02059 * math.sin(2 * gRad) * math.cos(gRad) +
                 0.000289 * math.sin(3 * gRad) * math.cos(1.5 * gRad) +
                 0.000147 * math.sin(4 * gRad) * math.cos(2 * gRad) +
                 0.000004 * math.sin(5 * gRad) * math.cos(2.5 * gRad) +
                 0.000001 * math.sin(6 * gRad) * math.cos(3 * gRad) +
                 0.004789 * math.sin(LRad) * math.cos(LRad / 2) +
                 0.000075 * math.sin(2 * LRad) * math.cos(LRad) +
                 0.000001 * math.sin(3 * LRad) * math.cos(1.5 * LRad);
    
    return eot * 4;
  }
  
  /// Calculate local apparent solar time
  /// Returns DateTime representing the apparent solar time
  DateTime calculateApparentSolarTime({
    required double latitude,
    required double longitude,
    DateTime? dateTime,
  }) {
    final now = dateTime ?? DateTime.now();
    final timezoneOffset = now.timeZoneOffset.inHours;
    final eot = calculateEquationOfTime(now);
    final lstm = 15.0 * timezoneOffset;
    final tc = 4 * (longitude - lstm) + eot;
    
    return now.add(Duration(minutes: tc.round()));
  }
  
  /// Calculate sunrise and sunset times
  Map<String, DateTime> calculateSunTimes({
    required double latitude,
    required double longitude,
    DateTime? date,
  }) {
    final targetDate = date ?? DateTime.now();
    final position = SunCalc.getTimes(targetDate, latitude, longitude);
    
    return {
      'sunrise': position[SunTimes.sunrise] ?? targetDate,
      'sunset': position[SunTimes.sunset] ?? targetDate,
      'solar_noon': position[SunTimes.solarNoon] ?? targetDate,
    };
  }
  
  /// Convert DateTime to Julian Date
  double _toJulianDate(DateTime date) {
    int year = date.year;
    int month = date.month;
    int day = date.day;
    
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    
    final a = (year / 100).floor();
    final b = 2 - a + (a / 4).floor();
    
    return (365.25 * (year + 4716)).floor() + 
           (30.6001 * (month + 1)).floor() + 
           day + b - 1524.5;
  }
}
