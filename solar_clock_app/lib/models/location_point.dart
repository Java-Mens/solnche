/// Represents a location with coordinates and optional name
class LocationPoint {
  final double latitude;
  final double longitude;
  final String? name;

  LocationPoint({
    required this.latitude,
    required this.longitude,
    this.name,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationPoint &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() => 'LocationPoint(lat: $latitude, lon: $longitude, name: $name)';
}
