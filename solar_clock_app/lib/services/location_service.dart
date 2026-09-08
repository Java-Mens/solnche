import 'package:geolocator/geolocator.dart';
import '../models/location_point.dart';

/// Service for handling location permissions and getting current position
class LocationService {
  /// Check if location permission is granted
  Future<bool> checkPermission() async {
    final status = await Geolocator.checkPermission();
    return status == LocationPermission.whileInUse || 
           status == LocationPermission.always;
  }
  
  /// Request location permission
  Future<bool> requestPermission() async {
    final status = await Geolocator.requestPermission();
    return status == LocationPermission.whileInUse || 
           status == LocationPermission.always;
  }
  
  /// Get current location
  Future<LocationPoint?> getCurrentLocation() async {
    try {
      bool hasPermission = await checkPermission();
      if (!hasPermission) {
        hasPermission = await requestPermission();
        if (!hasPermission) {
          return null;
        }
      }
      
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      
      return LocationPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        name: 'My Location',
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }
  
  /// Get current location as a stream
  Stream<LocationPoint?> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).map((position) => LocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      name: 'My Location',
    ));
  }
}