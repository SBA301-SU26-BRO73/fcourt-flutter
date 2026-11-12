import 'package:flutter/material.dart';

import '../../domain/entities/analytics.dart';
import 'compact_currency.dart';
import '../../../../app/theme/tokens.dart';

/// Bảng xếp hạng Top sân: huy chương Vàng, Bạc, Đồng cho hạng 1-3.
class TopCourtsWidget extends StatelessWidget {
  const TopCourtsWidget({super.key, required this.courts});

  final List<TopCourt> courts;

  static const gold = ChartColors.gold;
  static const silver = ChartColors.neutral;
  static const bronze = ChartColors.bronze;

  static Color? medalColor(int rank) => switch (rank) {
    1 => gold,
    2 => silver,
    3 => bronze,
    _ => null,
  };

  static String medalName(int rank) => switch (rank) {
    1 => 'Vàng',
    2 => 'Bạc',
    3 => 'Đồng',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    if (courts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Chưa có lượt đặt sân trong kỳ này')),
      );
    }
    return Column(
      children: [
        for (final court in courts)
          Padding(
            key: ValueKey('top-court-${court.rank}'),
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                _RankBadge(rank: court.rank),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        court.courtName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${court.bookings} lượt đặt',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatCompactVnd(court.revenue),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final color = TopCourtsWidget.medalColor(rank);
    if (color == null) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        child: Text(
          '$rank',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      );
    }
    return Tooltip(
      message: 'Huy chương ${TopCourtsWidget.medalName(rank)}',
      child: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.18),
        child: Icon(
          Icons.workspace_premium,
          key: ValueKey('medal-$rank'),
          color: color,
        ),
      ),
    );
  }
}
