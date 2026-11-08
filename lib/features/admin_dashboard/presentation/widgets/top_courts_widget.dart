import 'package:flutter/material.dart';

import '../../domain/entities/analytics.dart';
import 'compact_currency.dart';

/// Bảng xếp hạng Top sân: huy chương Vàng, Bạc, Đồng cho hạng 1-3.
class TopCourtsWidget extends StatelessWidget {
  const TopCourtsWidget({super.key, required this.courts});

  final List<TopCourt> courts;

  static const gold = Color(0xFFFFB300);
  static const silver = Color(0xFF90A4AE);
  static const bronze = Color(0xFFB87333);

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
          ListTile(
            key: ValueKey('top-court-${court.rank}'),
            contentPadding: EdgeInsets.zero,
            leading: _RankBadge(rank: court.rank),
            title: Text(
              court.courtName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('${court.bookings} lượt đặt'),
            trailing: Text(
              formatCompactVnd(court.revenue),
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
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
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text('$rank'),
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
