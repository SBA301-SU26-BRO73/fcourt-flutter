import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../app/widgets/fc_widgets.dart';
import '../../../../../app/widgets/sport_icon.dart';
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
              avatar: sport == null
                  ? null
                  : SportIcon.named(sport.label, size: 18),
              label: Text(sport?.label ?? 'Tất cả'),
              selected: selected == sport,
              onSelected: (_) => onSelected(sport),
            ),
          ),
      ],
    ),
  );
}

/// Placeholder for a branch without a photo: flat tonal block with the sport
/// icon. Never presented as a photograph of a venue.
class CourtArtwork extends StatelessWidget {
  const CourtArtwork({super.key, this.height, this.label, this.sport});

  /// Fixed height, or null to fill whatever the parent gives (e.g. 16:9).
  final double? height;
  final String? label;

  /// Sport the list is filtered to; its icon replaces the generic picture.
  final DiscoverySport? sport;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: height,
      width: double.infinity,
      color: colors.surfaceContainer,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          sport == null
              ? Icon(
                  Icons.image_outlined,
                  size: 32,
                  color: colors.onSurfaceVariant,
                )
              : SportIcon.named(
                  sport!.label,
                  size: 36,
                  color: colors.onSurfaceVariant,
                ),
          if (label != null && (height ?? 120) >= 120) ...[
            const SizedBox(height: Gap.xs),
            Text(
              label!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class BranchCard extends StatelessWidget {
  const BranchCard({super.key, required this.branch, required this.onTap});
  final Branch branch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: FcCard(
      padding: EdgeInsets.zero,
      clip: true,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CourtArtwork(height: 112),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branch.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
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
  Widget build(BuildContext context) => Center(
    child: EmptyState(
      icon: onRetry == null
          ? Icons.search_off_outlined
          : Icons.cloud_off_outlined,
      message: message,
      action: onRetry == null
          ? null
          : TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
    ),
  );
}
