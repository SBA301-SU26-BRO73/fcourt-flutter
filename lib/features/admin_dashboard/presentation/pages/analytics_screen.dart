import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../app/widgets/fc_widgets.dart';
import '../../domain/entities/analytics.dart';
import '../bloc/analytics_bloc.dart';
import '../widgets/compact_currency.dart';
import '../widgets/owner_ui.dart';
import '../widgets/occupancy_gauge.dart';
import '../widgets/peak_hours_bar_chart.dart';
import '../widgets/revenue_line_chart.dart';
import '../widgets/top_courts_widget.dart';

/// SCRUM-44 / SCRUM-75: phân tích doanh thu, tỷ lệ lấp đầy, Top sân và giờ cao
/// điểm của chủ sân.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phân tích')),
      body: BlocBuilder<AnalyticsBloc, AnalyticsState>(
        builder: (context, state) {
          final bloc = context.read<AnalyticsBloc>();
          return RefreshIndicator(
            onRefresh: () async {
              bloc.add(const AnalyticsRefreshed());
              await bloc.stream.firstWhere(
                (s) =>
                    s.revenue.status != AnalyticsLoadStatus.loading &&
                    s.insights.status != AnalyticsLoadStatus.loading,
              );
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(ownerPad, 0, ownerPad, Gap.xl),
              children: [
                OwnerBranchPicker(
                  key: ValueKey('analytics-branch-${state.branches.length}'),
                  branches: state.branches,
                  selectedId: state.selectedBranchId,
                  message: state.branchesMessage,
                  onSelected: (id) => bloc.add(AnalyticsBranchChanged(id)),
                ),
                _RevenueSection(state: state),
                const SizedBox(height: 13),
                _OccupancySection(state: state),
                const SizedBox(height: 13),
                _TopCourtsSection(state: state),
                const SizedBox(height: 13),
                _PeakHoursSection(state: state),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Khung thẻ chung: tiêu đề, bộ lọc (tuỳ chọn) và nội dung.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required super.key,
    required this.title,
    required this.child,
    this.filters,
  });

  final String title;
  final Widget? filters;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return OwnerCard(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (filters != null) ...[const SizedBox(height: 12), filters!],
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// Hiển thị một khối theo trạng thái: khung xương khi tải lần đầu, giữ dữ liệu
/// cũ (phủ mờ) khi đang tải lại, thông báo lỗi kèm nút thử lại khi thất bại.
class _SectionBody<T> extends StatelessWidget {
  const _SectionBody({
    required this.section,
    required this.height,
    required this.builder,
  });

  final AnalyticsSection<T> section;
  final double height;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    final data = section.data;
    if (section.status == AnalyticsLoadStatus.failure && data == null) {
      return SizedBox(
        height: height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text(
              section.message ?? 'Không tải được số liệu',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () =>
                  context.read<AnalyticsBloc>().add(const AnalyticsRefreshed()),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    if (data == null) {
      final scheme = Theme.of(context).colorScheme;
      return Shimmer.fromColors(
        key: const ValueKey('analytics-loading'),
        baseColor: scheme.surfaceContainerHighest,
        highlightColor: scheme.surface,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
        ),
      );
    }
    final loading = section.status == AnalyticsLoadStatus.loading;
    final failed = section.status == AnalyticsLoadStatus.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loading) const LinearProgressIndicator(minHeight: 2),
        if (failed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${section.message ?? 'Không cập nhật được số liệu'} '
              '(đang hiển thị số liệu trước đó)',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
        Opacity(opacity: loading ? 0.6 : 1, child: builder(data)),
      ],
    );
  }
}

class _RevenueSection extends StatelessWidget {
  const _RevenueSection({required this.state});

  final AnalyticsState state;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      key: const ValueKey('analytics-revenue'),
      title: 'Doanh thu',
      filters: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final range in RevenueRange.values)
            OwnerPill(
              range.label,
              key: ValueKey('range-${range.name}'),
              selected: state.range == range,
              onTap: () => context.read<AnalyticsBloc>().add(
                AnalyticsRangeChanged(range),
              ),
            ),
        ],
      ),
      child: _SectionBody<RevenueChart>(
        section: state.revenue,
        height: 220,
        builder: (chart) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tổng ${formatCompactVnd(chart.totalRevenue)} · '
              '${chart.totalBookings} lượt đặt',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            RevenueLineChart(chart: chart),
          ],
        ),
      ),
    );
  }
}

class _OccupancySection extends StatelessWidget {
  const _OccupancySection({required this.state});

  final AnalyticsState state;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      key: const ValueKey('analytics-occupancy'),
      title: 'Tỷ lệ lấp đầy',
      child: _SectionBody<RevenueChart>(
        section: state.revenue,
        height: 72,
        builder: (chart) => OccupancyGauge(rate: chart.occupancyRate),
      ),
    );
  }
}

class _TopCourtsSection extends StatelessWidget {
  const _TopCourtsSection({required this.state});

  final AnalyticsState state;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      key: const ValueKey('analytics-top-courts'),
      title: 'Top sân đặt nhiều nhất',
      filters: _PeriodFilter(selected: state.period),
      child: _SectionBody<CourtInsights>(
        section: state.insights,
        height: 200,
        builder: (insights) => TopCourtsWidget(courts: insights.topCourts),
      ),
    );
  }
}

class _PeakHoursSection extends StatelessWidget {
  const _PeakHoursSection({required this.state});

  final AnalyticsState state;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      key: const ValueKey('analytics-peak-hours'),
      title: 'Giờ cao điểm',
      child: _SectionBody<CourtInsights>(
        section: state.insights,
        height: 220,
        builder: (insights) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: PeakHoursBarChart.peakColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text('Giờ vàng', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            PeakHoursBarChart(hours: insights.peakHours),
          ],
        ),
      ),
    );
  }
}

class _PeriodFilter extends StatelessWidget {
  const _PeriodFilter({required this.selected});

  final AnalyticsPeriod selected;

  static const _labels = {
    AnalyticsPeriod.month: 'Tháng này',
    AnalyticsPeriod.quarter: 'Quý này',
    AnalyticsPeriod.year: 'Năm nay',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final period in AnalyticsPeriod.values)
          OwnerPill(
            _labels[period]!,
            key: ValueKey('period-${period.name}'),
            selected: selected == period,
            onTap: () => context.read<AnalyticsBloc>().add(
              AnalyticsPeriodChanged(period),
            ),
          ),
      ],
    );
  }
}
