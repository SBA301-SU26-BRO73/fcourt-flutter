import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/wp3b_widgets.dart';
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
        old.name != widget.name) {
      _probe();
    }
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
      if (mounted && revision == _revision) {
        setState(() {
          _availability = BranchMapAvailability.unavailable;
          _fallback = true;
        });
      }
    });
    BranchMapAvailability availability;
    try {
      availability = await widget.platform.availability();
    } catch (_) {
      availability = BranchMapAvailability.unavailable;
    }
    if (!mounted || revision != _revision || _availability != null) return;
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
    final revision = _revision;
    final colors = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 12, color: colors.onSurfaceVariant);
    void ready() {
      if (revision == _revision && !_fallback) _mapReady();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (location == null)
          Text('Chi nhánh chưa có tọa độ GPS hợp lệ.', style: muted)
        else ...[
          if (!location.supportsTiles)
            Text(
              'Tọa độ nằm ngoài vùng hiển thị bản đồ. Bạn vẫn có thể chỉ đường.',
              style: muted,
            )
          else if (_availability == null)
            SizedBox(
              height: 260,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(Radii.xl),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            )
          else
            Container(
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.xl),
                border: Border.all(color: colors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
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
                              ready,
                            ) ??
                            GoogleBranchMap(
                              key: ValueKey(location.coordinates),
                              location: location,
                              name: widget.name,
                              onReady: ready,
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
          if (_fallback && location.supportsTiles) ...[
            const SizedBox(height: Gap.sm),
            Text('Bản đồ dự phòng OpenStreetMap', style: muted),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _opening
                    ? null
                    : () => _open((p) => p.attribution()),
                child: const Text('© OpenStreetMap contributors'),
              ),
            ),
          ],
          const SizedBox(height: Gap.lg),
          Wp3bAction(
            'Chỉ đường đến sân',
            onPressed: _opening
                ? null
                : () => _open((p) => p.directions(location)),
          ),
          const SizedBox(height: Gap.sm),
          Wp3bAction(
            'Mở OpenStreetMap',
            kind: Wp3bActionKind.tonal,
            onPressed: _opening
                ? null
                : () => _open((p) => p.openStreetMap(location)),
          ),
          if (!_fallback && _availability != null && location.supportsTiles)
            Wp3bAction(
              'Xem bản đồ dự phòng',
              kind: Wp3bActionKind.text,
              onPressed: _useFallback,
            ),
          if (_fallback)
            Wp3bAction(
              'Thử lại bản đồ',
              kind: Wp3bActionKind.text,
              onPressed: _probe,
            ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: Gap.sm),
            child: Text(_error!, style: TextStyle(color: colors.error)),
          ),
      ],
    );
  }
}
