import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/discovery_repository.dart';

String branchPrice(Branch branch) => branch.minPrice == null
    ? 'Giá chưa cập nhật'
    : 'Từ ${NumberFormat.decimalPattern('vi').format(branch.minPrice)} đ/slot';

class SportFilters extends StatelessWidget {
  const SportFilters({super.key, this.selected, required this.onSelected});
  final DiscoverySport? selected;
  final ValueChanged<DiscoverySport?> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final sport in <DiscoverySport?>[null, ...DiscoverySport.values])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(
                sport == DiscoverySport.badminton
                    ? Icons.sports
                    : Icons.sports_tennis,
                size: 18,
              ),
              label: Text(sport?.label ?? 'Tất cả'),
              selected: selected == sport,
              onSelected: (_) => onSelected(sport),
            ),
          ),
      ],
    ),
  );
}

/// Decorative court artwork, never presented as a photograph of a venue.
class CourtArtwork extends StatelessWidget {
  const CourtArtwork({super.key, this.height = 150, this.label = 'FCOURT'});
  final double height;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    width: double.infinity,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF4648D4), Color(0xFF006C49)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _CourtPainter())),
        Positioned(
          left: 16,
          bottom: 14,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Positioned(
          right: 18,
          top: 18,
          child: Icon(Icons.sports_tennis, color: Colors.white70, size: 42),
        ),
      ],
    ),
  );
}

class _CourtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final court = Rect.fromLTWH(
      size.width * .42,
      -18,
      size.width * .5,
      size.height + 42,
    );
    canvas.drawRect(court, paint);
    canvas.drawLine(
      Offset(court.center.dx, court.top),
      Offset(court.center.dx, court.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(court.left, court.center.dy),
      Offset(court.right, court.center.dy),
      paint,
    );
    canvas.drawRect(court.deflate(18), paint);
  }

  @override
  bool shouldRepaint(_CourtPainter oldDelegate) => false;
}

class BranchCard extends StatelessWidget {
  const BranchCard({super.key, required this.branch, required this.onTap});
  final Branch branch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CourtArtwork(label: 'Ảnh sân chưa cập nhật'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branch.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    branch.address,
                    branch.district,
                    branch.city,
                  ].whereType<String>().where((s) => s.isNotEmpty).join(', '),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    LabelIcon(
                      Icons.location_on_outlined,
                      branch.distanceKm == null
                          ? 'Chưa có khoảng cách'
                          : '${branch.distanceKm!.toStringAsFixed(1)} km',
                    ),
                    const LabelIcon(
                      Icons.star_border_rounded,
                      'Chưa có đánh giá',
                    ),
                    LabelIcon(
                      Icons.grid_view_rounded,
                      '${branch.courtCount} sân',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  branchPrice(branch),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class LabelIcon extends StatelessWidget {
  const LabelIcon(this.icon, this.label, {super.key});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: 4),
      Flexible(child: Text(label)),
    ],
  );
}

class DiscoveryMessage extends StatelessWidget {
  const DiscoveryMessage({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.sports_tennis,
          size: 40,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        if (onRetry != null)
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
      ],
    ),
  );
}
