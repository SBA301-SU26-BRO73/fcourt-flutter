import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../app/widgets/fc_widgets.dart';
import '../../../../../app/widgets/wp3b_widgets.dart';
import '../../domain/discovery_repository.dart';

/// Price line shown on cards: "Từ 50.000đ/giờ".
String branchPrice(Branch branch) => branch.minPrice == null
    ? 'Giá chưa cập nhật'
    : 'Từ ${NumberFormat.decimalPattern('vi').format(branch.minPrice)}đ/giờ';

extension DiscoverySportKind on DiscoverySport {
  SportKind get kind => switch (this) {
    DiscoverySport.badminton => SportKind.badminton,
    DiscoverySport.pickleball => SportKind.pickleball,
    DiscoverySport.tennis => SportKind.tennis,
    DiscoverySport.football => SportKind.football,
  };
}

/// "48 Văn Cao, Ba Đình, Hà Nội · 1,2 km".
String branchSubtitle(Branch branch) {
  final address = [
    branch.address,
    branch.district,
    branch.city,
  ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
  final km = branch.distanceKm;
  if (km == null) return address;
  final distance = '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  return address.isEmpty ? distance : '$address · $distance';
}

/// Mock-up "court" card for a branch: photo, sport chip, rank, name,
/// address, price and rating. Opens the branch detail on tap.
class BranchPhotoCard extends StatelessWidget {
  const BranchPhotoCard({
    super.key,
    required this.branch,
    this.sport,
    this.rank,
  });
  final Branch branch;
  final DiscoverySport? sport;
  final int? rank;

  @override
  Widget build(BuildContext context) => PhotoCard(
    title: branch.name,
    imageUrl: branch.imageUrl,
    sportKind: sport?.kind ?? SportKind.badminton,
    sportLabel: sport?.label,
    badge: rank == null ? null : '#$rank',
    subtitle: branchSubtitle(branch),
    priceText: branchPrice(branch),
    ratingText: branch.reviewCount > 0
        ? '${branch.averageRating.toStringAsFixed(1).replaceAll('.', ',')} (${branch.reviewCount})'
        : 'Mới',
    onTap: () => context.push('/branches/${branch.id}', extra: branch),
  );
}

/// Sport filter chips for the search and filter sheets.
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

class BranchCard extends StatelessWidget {
  const BranchCard({super.key, required this.branch, required this.onTap});
  final Branch branch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: PhotoCard(
      title: branch.name,
      imageUrl: branch.imageUrl,
      subtitle: branchSubtitle(branch),
      priceText: branchPrice(branch),
      ratingText: branch.reviewCount > 0
          ? '${branch.averageRating.toStringAsFixed(1).replaceAll('.', ',')} (${branch.reviewCount})'
          : 'Mới',
      onTap: onTap,
    ),
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
