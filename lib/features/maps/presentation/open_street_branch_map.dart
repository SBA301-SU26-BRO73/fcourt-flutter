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
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 36,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(widget.name, textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text(
                        'Bản đồ tạm thời không khả dụng. Dùng Chỉ đường bên dưới.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
