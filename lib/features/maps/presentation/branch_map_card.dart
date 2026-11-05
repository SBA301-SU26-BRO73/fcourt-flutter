import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/branch_location.dart';
import 'google_branch_map.dart';
import 'open_street_branch_map.dart';

typedef NativeBranchMapBuilder = Widget Function(
  BranchLocation location,
  String name,
  VoidCallback ready,
);
typedef FallbackBranchMapBuilder = Widget Function(
  BranchLocation location,
  String name,
);

class BranchMapCard extends StatefulWidget {
  const BranchMapCard({
    super.key,
    required this.location,
    required this.name,
    required this.platform,
    this.nativeBuilder,
    this.fallbackBuilder,
  });
  final BranchLocation? location;
  final String name;
  final BranchMapPlatform platform;
  final NativeBranchMapBuilder? nativeBuilder;
  final FallbackBranchMapBuilder? fallbackBuilder;
  @override
  State<BranchMapCard> createState() => _BranchMapCardState();
}

class _BranchMapCardState extends State<BranchMapCard> {
  BranchMapAvailability? _availability;
  bool _fallback = false, _opening = false, _ready = false;
  int _revision = 0;
  String? _error;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _probe();
  }

  @override
  void didUpdateWidget(BranchMapCard old) {
    super.didUpdateWidget(old);
    if (old.location?.coordinates != widget.location?.coordinates ||
        old.platform != widget.platform ||
        old.name != widget.name)
      _probe();
  }

  Future<void> _probe() async {
    final revision = ++_revision;
    _timer?.cancel();
    setState(() {
      _availability = null;
      _fallback = false;
      _ready = false;
      _error = null;
      _opening = false;
    });
    if (widget.location == null || !widget.location!.supportsTiles) return;
    _timer = Timer(const Duration(seconds: 5), () {
      if (mounted && revision == _revision)
        setState(() {
          _availability = BranchMapAvailability.unavailable;
          _fallback = true;
        });
    });
    BranchMapAvailability availability;
    try {
      availability = await widget.platform.availability();
    } catch (_) {
      availability = BranchMapAvailability.unavailable;
    }
    if (!mounted || revision != _revision) return;
    _timer?.cancel();
    setState(() {
      _availability = availability;
      _fallback = availability != BranchMapAvailability.available;
    });
    if (!_fallback) _timer = Timer(const Duration(seconds: 12), _useFallback);
  }

  void _useFallback() {
    _timer?.cancel();
    if (mounted) setState(() => _fallback = true);
  }

  void _mapReady() {
    _timer?.cancel();
    if (mounted && !_ready) setState(() => _ready = true);
  }

  Future<void> _open(
    Future<bool> Function(BranchMapPlatform platform) action,
  ) async {
    if (_opening) return;
    final revision = _revision;
    setState(() {
      _opening = true;
      _error = null;
    });
    var success = false;
    try {
      success = await action(widget.platform);
    } catch (_) {
      /* Show retry below. */
    }
    if (!mounted || revision != _revision) return;
    setState(() {
      _opening = false;
      _error = success ? null : 'Chưa mở được bản đồ. Vui lòng thử lại.';
    });
  }

  @override
  void dispose() {
    _revision++;
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vị trí chi nhánh', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (location == null)
          const Text('Chi nhánh chưa có tọa độ GPS hợp lệ.')
        else ...[
          if (!location.supportsTiles)
            const Text(
              'Tọa độ nằm ngoài vùng hiển thị bản đồ. Bạn vẫn có thể chỉ đường.',
            )
          else if (_availability == null)
            const SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SizedBox(
              height: 260,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _fallback
                    ? widget.fallbackBuilder?.call(location, widget.name) ??
                          OpenStreetBranchMap(
                            key: ValueKey(location.coordinates),
                            location: location,
                            name: widget.name,
                          )
                    : Stack(
                        children: [
                          widget.nativeBuilder?.call(
                                location,
                                widget.name,
                                _mapReady,
                              ) ??
                              GoogleBranchMap(
                                key: ValueKey(location.coordinates),
                                location: location,
                                name: widget.name,
                                onReady: _mapReady,
                              ),
                          if (!_ready)
                            const Positioned(
                              top: 8,
                              left: 8,
                              right: 8,
                              child: LinearProgressIndicator(),
                            ),
                        ],
                      ),
              ),
            ),
          if (_fallback && location.supportsTiles) ...[
            const Text('Bản đồ dự phòng OpenStreetMap'),
            TextButton(
              onPressed: _opening ? null : () => _open((p) => p.attribution()),
              child: const Text('© OpenStreetMap contributors'),
            ),
          ],
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _opening
                    ? null
                    : () => _open((p) => p.directions(location)),
                icon: const Icon(Icons.directions),
                label: const Text('Chỉ đường đến sân'),
              ),
              TextButton(
                onPressed: _opening
                    ? null
                    : () => _open((p) => p.openStreetMap(location)),
                child: const Text('Mở OpenStreetMap'),
              ),
            ],
          ),
          if (!_fallback && _availability != null && location.supportsTiles)
            TextButton(
              onPressed: _useFallback,
              child: const Text('Xem bản đồ dự phòng'),
            ),
          if (_fallback)
            TextButton(onPressed: _probe, child: const Text('Thử lại bản đồ')),
        ],
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}
