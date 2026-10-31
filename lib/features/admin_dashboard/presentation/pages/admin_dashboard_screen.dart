import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import '../../domain/entities/dashboard_stats.dart';
import '../bloc/dashboard_bloc.dart';
import '../widgets/booking_status_pie_chart.dart';
import '../widgets/compact_currency.dart';

/// SCRUM-13: tổng quan doanh thu, lượt đặt, sân hoạt động và tỷ lệ lấp đầy.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key, this.onOpenBranches});

  final VoidCallback? onOpenBranches;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tổng quan'),
        actions: [
          if (onOpenBranches != null)
            IconButton(
              tooltip: 'Chi nhánh',
              icon: const Icon(Icons.store_mall_directory_outlined),
              onPressed: onOpenBranches,
            ),
        ],
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          final bloc = context.read<DashboardBloc>();
          return RefreshIndicator(
            onRefresh: () async {
              bloc.add(const DashboardRefreshed());
              await bloc.stream.firstWhere(
                (s) => s.status != DashboardStatus.loading,
              );
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _BranchDropdown(state: state),
                const SizedBox(height: 16),
                ..._content(context, state),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _content(BuildContext context, DashboardState state) {
    final stats = state.stats;
    switch (state.status) {
      case DashboardStatus.loading:
        // Lần tải đầu: khung xương. Đổi chi nhánh: giữ biểu đồ đang hiển thị
        // để fl_chart chuyển động mượt sang số liệu mới, chỉ phủ shimmer lên
        // các thẻ số liệu.
        if (stats == null) return const [DashboardSkeleton()];
        return _statsContent(context, stats, loading: true);
      case DashboardStatus.failure:
        return [
          const SizedBox(height: 48),
          Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            state.message ?? 'Không tải được số liệu',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Center(
            child: FilledButton.tonal(
              onPressed: () =>
                  context.read<DashboardBloc>().add(const DashboardRefreshed()),
              child: const Text('Thử lại'),
            ),
          ),
        ];
      case DashboardStatus.success:
        if (stats == null) return const [];
        return _statsContent(context, stats, loading: false);
    }
  }

  List<Widget> _statsContent(
    BuildContext context,
    DashboardStats stats, {
    required bool loading,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final grid = _StatGrid(stats: stats);
    return [
      loading
          ? Shimmer.fromColors(
              key: const ValueKey('dashboard-stats-loading'),
              baseColor: scheme.surfaceContainerHighest,
              highlightColor: scheme.surface,
              child: grid,
            )
          : grid,
      const SizedBox(height: 16),
      Card(
        key: const ValueKey('dashboard-chart'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trạng thái đặt sân',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              BookingStatusPieChart(counts: stats.bookingStatusCounts),
            ],
          ),
        ),
      ),
    ];
  }
}

class _BranchDropdown extends StatelessWidget {
  const _BranchDropdown({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final selected = state.branches.any((b) => b.id == state.selectedBranchId)
        ? state.selectedBranchId
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int?>(
          key: ValueKey('dashboard-branch-${state.branches.length}'),
          initialValue: selected,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Chi nhánh',
            prefixIcon: Icon(Icons.store_mall_directory_outlined),
          ),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Tất cả chi nhánh'),
            ),
            for (final branch in state.branches)
              DropdownMenuItem<int?>(
                value: branch.id,
                child: Text(branch.name),
              ),
          ],
          onChanged: (id) =>
              context.read<DashboardBloc>().add(DashboardBranchChanged(id)),
        ),
        if (state.branchesMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(
              'Không tải được danh sách chi nhánh: ${state.branchesMessage}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final cards = [
      StatCard(
        icon: Icons.payments_outlined,
        color: const Color(0xFF2E7D32),
        label: 'Tổng doanh thu',
        value: formatCompactVnd(stats.totalRevenue),
        caption: 'Hôm nay ${formatCompactVnd(stats.todayRevenue)}',
      ),
      StatCard(
        icon: Icons.event_available_outlined,
        color: const Color(0xFF1565C0),
        label: 'Lượt đặt sân',
        value: '${stats.totalBookings}',
      ),
      StatCard(
        icon: Icons.sports_tennis,
        color: const Color(0xFF6A1B9A),
        label: 'Sân hoạt động',
        value: '${stats.activeCourts}/${stats.totalCourts}',
      ),
      StatCard(
        icon: Icons.donut_large,
        color: const Color(0xFFEF6C00),
        label: 'Tỷ lệ lấp đầy',
        value: formatPercent(stats.occupancyRate),
      ),
    ];
    return _TwoColumnGrid(children: cards);
  }
}

/// Lưới 2x2 không cuộn riêng (nằm trong ListView của màn hình).
class _TwoColumnGrid extends StatelessWidget {
  const _TwoColumnGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: 1.25,
    children: children,
  );
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.caption,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 18),
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(label, style: textTheme.bodySmall),
            if (caption != null)
              Text(
                caption!,
                style: textTheme.labelSmall?.copyWith(color: color),
              ),
          ],
        ),
      ),
    );
  }
}

/// Khung xương lấp lánh (Shimmer) khi đang tải số liệu.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget block({double? height}) => Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest,
      highlightColor: scheme.surface,
      child: Column(
        children: [
          _TwoColumnGrid(children: [for (var i = 0; i < 4; i++) block()]),
          const SizedBox(height: 16),
          block(height: 260),
        ],
      ),
    );
  }
}
