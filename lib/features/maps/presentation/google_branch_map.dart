import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/branch_location.dart';

class GoogleBranchMap extends StatelessWidget {
  const GoogleBranchMap({
    super.key,
    required this.location,
    required this.name,
    required this.onReady,
  });
  final BranchLocation location;
  final String name;
  final VoidCallback onReady;
  @override
  Widget build(BuildContext context) {
    final point = LatLng(location.latitude, location.longitude);
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: point, zoom: 16),
      markers: {
        Marker(
          markerId: const MarkerId('branch'),
          position: point,
          infoWindow: InfoWindow(title: name),
        ),
      },
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
      onMapCreated: (_) => onReady(),
    );
  }
}
