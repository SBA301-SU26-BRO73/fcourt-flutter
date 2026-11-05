class BranchLocation {
  const BranchLocation._(this.latitude, this.longitude);
  final double latitude, longitude;
  static BranchLocation? parse(Object? latitude, Object? longitude) {
    if (latitude is! num ||
        longitude is! num ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180)
      return null;
    return BranchLocation._(latitude.toDouble(), longitude.toDouble());
  }

  String get coordinates => '$latitude,$longitude';
  bool get supportsTiles => latitude.abs() <= 85.05112878;
  Uri get androidDirections =>
      Uri(scheme: 'google.navigation', queryParameters: {'q': coordinates});
  Uri get googleDirections => Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': coordinates,
    'dir_action': 'navigate',
  });
  Uri get appleDirections =>
      Uri.https('maps.apple.com', '/', {'daddr': coordinates, 'dirflg': 'd'});
  Uri get openStreetMap => Uri.https('www.openstreetmap.org', '/', {
    'mlat': '$latitude',
    'mlon': '$longitude',
  }).replace(fragment: 'map=16/$latitude/$longitude');
}

enum BranchMapAvailability { available, missingKey, unavailable }

abstract interface class BranchMapPlatform {
  Future<BranchMapAvailability> availability();
  Future<bool> directions(BranchLocation location);
  Future<bool> openStreetMap(BranchLocation location);
  Future<bool> attribution();
}
