import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_point.dart';

/// Provider for managing solar time state and location comparison
class SolarTimeProvider with ChangeNotifier {
  LocationPoint? _currentLocation;
  LocationPoint? _comparisonLocation;
  DateTime _lastUpdated = DateTime.now();
  
  LocationPoint? get currentLocation => _currentLocation;
  LocationPoint? get comparisonLocation => _comparisonLocation;
  DateTime get lastUpdated => _lastUpdated;
  
  bool get isComparing => _comparisonLocation != null;
  
  /// Set current location
  void setCurrentLocation(LocationPoint? location) {
    _currentLocation = location;
    _lastUpdated = DateTime.now();
    notifyListeners();
  }
  
  /// Set comparison location
  void setComparisonLocation(LocationPoint? location) {
    _comparisonLocation = location;
    notifyListeners();
  }
  
  /// Clear comparison location
  void clearComparisonLocation() {
    _comparisonLocation = null;
    notifyListeners();
  }
  
  /// Load saved comparison location from preferences
  Future<void> loadSavedLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('comparison_lat');
    final lon = prefs.getDouble('comparison_lon');
    final name = prefs.getString('comparison_name');
    
    if (lat != null && lon != null) {
      _comparisonLocation = LocationPoint(
        latitude: lat,
        longitude: lon,
        name: name,
      );
      notifyListeners();
    }
  }
  
  /// Save comparison location to preferences
  Future<void> saveComparisonLocation() async {
    final prefs = await SharedPreferences.getInstance();
    if (_comparisonLocation != null) {
      await prefs.setDouble('comparison_lat', _comparisonLocation!.latitude);
      await prefs.setDouble('comparison_lon', _comparisonLocation!.longitude);
      if (_comparisonLocation!.name != null) {
        await prefs.setString('comparison_name', _comparisonLocation!.name!);
      }
    } else {
      await prefs.remove('comparison_lat');
      await prefs.remove('comparison_lon');
      await prefs.remove('comparison_name');
    }
  }
}
