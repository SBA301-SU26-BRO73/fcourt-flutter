import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../app/widgets/fc_widgets.dart';
import '../../../report_export/domain/report_export.dart';
import '../../../report_export/presentation/revenue_export_button.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../bloc/dashboard_bloc.dart';
import '../widgets/booking_status_pie_chart.dart';
import '../widgets/owner_ui.dart';
import '../widgets/week_revenue_chart.dart';

/// SCRUM-13: tổng quan doanh thu (mockup 06): banner doanh thu, lấp đầy và số
/// đơn, doanh thu 7 ngày, trạng thái đơn.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({
    super.key,
    this.exportRepository,
    this.fileOpener,
  });

  /// SCRUM-77: có cả hai thì thanh công cụ có nút xuất báo cáo doanh thu.
  final RevenueReportRepository? exportRepository;
  final ReportFileOpener? fileOpener;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tổng quan doanh thu'),
        actions: [
          if (exportRepository != null && fileOpener != null)
            BlocBuilder<DashboardBloc, DashboardState>(
              buildWhen: (a, b) =>
                  a.branches != b.branches ||
                  a.selectedBranchId != b.selectedBranchId,
              builder: (context, state) => RevenueExportButton(
                repository: exportRepository!,
                opener: fileOpener!,
                branches: state.branches,
                initialBranchId: state.selectedBranchId,
              ),
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
              padding: const EdgeInsets.fromLTRB(ownerPad, 0, ownerPad, Gap.xl),
              children: [
                OwnerBranchPicker(
                  key: ValueKey('dashboard-branch-${state.branches.length}'),
                  branches: state.branches,
                  selectedId: state.selectedBranchId,
                  message: state.branchesMessage,
                  onSelected: (id) => bloc.add(DashboardBranchChanged(id)),
                ),
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
        // Lần tải đầu: khung xương. Đổi chi nhánh: giữ số liệu đang hiển thị
        // và phủ shimmer lên khối số liệu.
        if (stats == null) return const [DashboardSkeleton()];
        return _statsContent(context, state, stats, loading: true);
      case DashboardStatus.failure:
        return [
          const SizedBox(height: 48),
          OwnerMessage(
            icon: Icons.cloud_off_outlined,
            text: state.message ?? 'Không tải được số liệu',
            action: 'Thử lại',
            onAction: () =>
                context.read<DashboardBloc>().add(const DashboardRefreshed()),
          ),
        ];
      case DashboardStatus.success:
        if (stats == null) return const [];
        return _statsContent(context, state, stats, loading: false);
    }
  }

  List<Widget> _statsContent(
    BuildContext context,
    DashboardState state,
    DashboardStats stats, {
    required bool loading,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final figures = _Figures(stats: stats);
    final week = state.weekRevenue;
    final updated = state.updatedAt ?? DateTime.now();
    return [
      loading
          ? Shimmer.fromColors(
              key: const ValueKey('dashboard-stats-loading'),
              baseColor: scheme.surfaceContainerHighest,
              highlightColor: scheme.surface,
              child: figures,
            )
          : figures,
      if (week != null && week.points.isNotEmpty)
        _Panel(
          key: const ValueKey('dashboard-week'),
          title: 'Doanh thu 7 ngày',
          trailing: 'Triệu đồng',
          bottom:
              '${DateFormat('dd').format(week.from)}–'
              '${DateFormat('dd/MM/yyyy').format(week.to)} · '
              'Cập nhật lúc ${DateFormat('HH:mm').format(updated)}',
          child: WeekRevenueChart(points: week.points),
        ),
      _Panel(
        key: const ValueKey('dashboard-chart'),
        title: 'Trạng thái đơn',
        child: BookingStatusPieChart(counts: stats.bookingStatusCounts),
      ),
    ];
  }
}

/// Banner doanh thu + hai thẻ lấp đầy / số đơn.
class _Figures extends StatelessWidget {
  const _Figures({required this.stats});

  final DashboardStats stats;

  static String _vnd(int v) => NumberFormat.decimalPattern('vi_VN').format(v);

  static String _percent(double ratio) {
    final value = (ratio * 1000).roundToDouble() / 10;
    return value == value.roundToDouble()
        ? '${value.toInt()}'
        : value.toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final good = context.fc.success.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OwnerCard(
          radius: 23,
          padding: const EdgeInsets.all(18),
          color: colors.primaryContainer,
          bordered: false,
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const OwnerNote('Tổng doanh thu'),
                const SizedBox(height: 7),
                _Big(_vnd(stats.totalRevenue), 'đ', size: 34, unit: 20),
                const SizedBox(height: 9),
                Text(
                  'Hôm nay ${_vnd(stats.todayRevenue)}đ',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: good,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 17),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: OwnerCard(
                    radius: 20,
                    padding: const EdgeInsets.fromLTRB(15, 18, 15, 17),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const OwnerNote('Tỷ lệ lấp đầy'),
                        const SizedBox(height: 8),
                        _Big(_percent(stats.occupancyRate), '%'),
                        const SizedBox(height: 9),
                        const OwnerNote('Trong kỳ báo cáo'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OwnerCard(
                    radius: 20,
                    padding: const EdgeInsets.fromLTRB(15, 18, 15, 17),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const OwnerNote('Số đơn'),
                        const SizedBox(height: 8),
                        _Big('${stats.totalBookings}', ''),
                        const SizedBox(height: 9),
                        OwnerNote(
                          '${stats.activeCourts}/${stats.totalCourts} sân hoạt động',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Số lớn kèm đơn vị nhỏ (`34px` + `20px`, hoặc `28px` + `17px`).
class _Big extends StatelessWidget {
  const _Big(this.value, this.unitText, {this.size = 28, this.unit = 17});
  final String value, unitText;
  final double size, unit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = size > 30;
    final color = accent ? colors.primary : colors.onSurface;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          text: value,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w700,
            letterSpacing: accent ? -1.2 : -.5,
            height: accent ? 1.28 : 1.2,
            color: color,
          ),
          children: [
            if (unitText.isNotEmpty)
              TextSpan(
                text: unitText,
                style: TextStyle(fontSize: unit, fontWeight: FontWeight.w700),
              ),
          ],
        ),
      ),
    );
  }
}

/// Khung biểu đồ (`.chart-panel`): viền 1px, bo 22, đệm 16.
class _Panel extends StatelessWidget {
  const _Panel({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.bottom,
  });
  final String title;
  final Widget child;
  final String? trailing, bottom;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: OwnerCard(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  if (trailing != null) OwnerNote(trailing!, size: 9),
                ],
              ),
              const SizedBox(height: 14),
              child,
              if (bottom != null) ...[
                const SizedBox(height: 13),
                OwnerNote(bottom!, size: 9),
              ],
            ],
          ),
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
    Widget block(double height, double radius) => Container(
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest,
      highlightColor: scheme.surface,
      child: Column(
        children: [
          block(120, 23),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: block(110, 20)),
              const SizedBox(width: 12),
              Expanded(child: block(110, 20)),
            ],
          ),
          const SizedBox(height: 17),
          block(220, 22),
        ],
      ),
    );
  }
}
