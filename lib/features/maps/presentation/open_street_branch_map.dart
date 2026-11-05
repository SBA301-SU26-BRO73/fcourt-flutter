import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../domain/branch_location.dart';

class OpenStreetBranchMap extends StatefulWidget {
  const OpenStreetBranchMap({
    super.key,
    required this.location,
    required this.name,
    this.tileProvider,
  });
  final BranchLocation location;
  final String name;
  final TileProvider? tileProvider;
  @override
  State<OpenStreetBranchMap> createState() => _OpenStreetBranchMapState();
}

class _OpenStreetBranchMapState extends State<OpenStreetBranchMap> {
  bool _tileError = false;
  void _error() {
    if (_tileError || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_tileError) setState(() => _tileError = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(widget.location.latitude, widget.location.longitude);
    return Stack(
      children: [
        FlutterMap(
          key: ValueKey(widget.location.coordinates),
          options: MapOptions(
            initialCenter: point,
            initialZoom: 16,
            maxZoom: 19,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.bro73.fcourt',
              tileProvider: widget.tileProvider,
              maxNativeZoom: 19,
              errorTileCallback: (_, _, _) => _error(),
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 180,
                  height: 90,
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Text(
                                widget.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.location_pin,
                        size: 32,
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_tileError)
          const Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Material(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Không tải được nền bản đồ. Bạn vẫn có thể chỉ đường.',
                ),
              ),
            ),
          ),
      ],
    );
  }
}
