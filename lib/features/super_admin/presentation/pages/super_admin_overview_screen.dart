import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../admin_dashboard/presentation/widgets/compact_currency.dart';
import '../../domain/entities/platform_overview.dart';
import '../bloc/platform_overview_cubit.dart';
import '../widgets/growth_line_chart.dart';
import '../../../../app/theme/tokens.dart';

/// SCRUM-79: trung tâm thống kê vĩ mô toàn nền tảng. Cần [PlatformOverviewCubit]
/// phía trên trong cây widget.
class SuperAdminOverviewScreen extends StatelessWidget {
  const SuperAdminOverviewScreen({super.key});

  /// Điện thoại 2 cột thẻ KPI; máy tính bảng từ 720dp trở lên 4 cột và đặt biểu
  /// đồ cạnh bảng top chủ sân.
  static const tabletBreakpoint = 720.0;
  static const monthOptions = [6, 12, 24];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê nền tảng'),
        actions: [
          BlocBuilder<PlatformOverviewCubit, PlatformOverviewState>(
            builder: (context, state) => IconButton(
              tooltip: 'Tải lại',
              onPressed: state.status == PlatformOverviewStatus.loading
                  ? null
                  : () => context.read<PlatformOverviewCubit>().load(),
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: BlocBuilder<PlatformOverviewCubit, PlatformOverviewState>(
        builder: (context, state) {
          final overview = state.overview;
          if (overview == null) {
            if (state.status == PlatformOverviewStatus.failure) {
              return _Failure(message: state.message);
            }
            return const Center(
              key: ValueKey('overview-loading'),
              child: CircularProgressIndicator(),
            );
          }
          final cubit = context.read<PlatformOverviewCubit>();
          return RefreshIndicator(
            onRefresh: () async {
              cubit.load();
              await cubit.stream.firstWhere(
                (s) => s.status != PlatformOverviewStatus.loading,
              );
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tablet = constraints.maxWidth >= tabletBreakpoint;
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (state.status == PlatformOverviewStatus.failure)
                      _StaleBanner(message: state.message),
                    if (state.status == PlatformOverviewStatus.loading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: LinearProgressIndicator(
                          key: ValueKey('overview-refreshing'),
                        ),
                      ),
                    _KpiGrid(overview: overview, columns: tablet ? 4 : 2),
                    const SizedBox(height: 16),
                    if (tablet)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _GrowthCard(
                              overview: overview,
                              months: state.months,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: _TopOwnersCard(owners: overview.topOwners),
                          ),
                        ],
                      )
                    else ...[
                      _GrowthCard(overview: overview, months: state.months),
                      const SizedBox(height: 16),
                      _TopOwnersCard(owners: overview.topOwners),
                    ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.overview, required this.columns});

  final PlatformOverview overview;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiCard(
        key: const ValueKey('kpi-gmv'),
        icon: Icons.payments_outlined,
        color: ChartColors.success,
        label: 'Tổng GMV đặt sân',
        value: formatCompactVnd(overview.gmv),
        caption: 'Doanh thu đặt sân qua hệ thống',
      ),
      _KpiCard(
        key: const ValueKey('kpi-saas'),
        icon: Icons.workspace_premium_outlined,
        color: ChartColors.accent,
        label: 'Doanh thu gói SaaS',
        value: formatCompactVnd(overview.saasRevenue),
        caption: 'Chủ sân mua gói',
      ),
      _KpiCard(
        key: const ValueKey('kpi-branches'),
        icon: Icons.store_mall_directory_outlined,
        color: ChartColors.info,
        label: 'Tổng chi nhánh',
        value: '${overview.branches.total}',
        caption: '${overview.branches.active} hoạt động · ${overview.courts} sân',
      ),
      _KpiCard(
        key: const ValueKey('kpi-customers'),
        icon: Icons.groups_outlined,
        color: ChartColors.peak,
        label: 'Khách hàng hoạt động',
        value: '${overview.customers.active}',
        caption:
            'Trên ${overview.customers.total} khách · chủ sân '
            '${overview.owners.active} (${overview.owners.pending} chờ duyệt)',
      ),
    ];
    // Chiều cao thẻ theo nội dung (chữ lớn, màn hẹp vẫn không tràn): mỗi hàng
    // đồng đều nhau nhờ IntrinsicHeight.
    return Column(
      children: [
        for (var start = 0; start < cards.length; start += columns)
          Padding(
            padding: EdgeInsets.only(top: start == 0 ? 0 : 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = start; i < start + columns; i++) ...[
                    if (i > start) const SizedBox(width: 12),
                    Expanded(child: i < cards.length ? cards[i] : const SizedBox()),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 2),
            Text(caption, style: textTheme.labelSmall?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _GrowthCard extends StatelessWidget {
  const _GrowthCard({required this.overview, required this.months});

  final PlatformOverview overview;
  final int months;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PlatformOverviewCubit>();
    return Card(
      key: const ValueKey('growth-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tăng trưởng tài khoản và dòng tiền',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              key: const ValueKey('overview-months'),
              segments: [
                for (final m in SuperAdminOverviewScreen.monthOptions)
                  ButtonSegment(value: m, label: Text('$m tháng')),
              ],
              selected: {months},
              showSelectedIcon: false,
              onSelectionChanged: (s) => cubit.load(months: s.first),
            ),
            const SizedBox(height: 16),
            GrowthLineChart(points: overview.monthly),
            const SizedBox(height: 8),
            Text(
              'Mỗi đường được chuẩn hóa theo mức cao nhất của chính nó; chạm vào '
              'một tháng để xem số thật.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopOwnersCard extends StatelessWidget {
  const _TopOwnersCard({required this.owners});

  final List<TopOwner> owners;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('top-owners-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top 5 chủ sân doanh thu cao nhất',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (owners.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Chưa có doanh thu đặt sân')),
              )
            else
              for (var i = 0; i < owners.length; i++)
                ListTile(
                  key: ValueKey('top-owner-${owners[i].ownerId}'),
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 14,
                    child: Text('${i + 1}'),
                  ),
                  title: Text(
                    owners[i].ownerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('${owners[i].branches} chi nhánh'),
                  trailing: Text(
                    formatCompactVnd(owners[i].revenue),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            message ?? 'Không tải được thống kê',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => context.read<PlatformOverviewCubit>().load(),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );
}

/// Lỗi khi đã có dữ liệu cũ: giữ số liệu cũ nhưng nói rõ là chưa làm mới được.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: MaterialBanner(
      key: const ValueKey('overview-stale'),
      content: Text(
        '${message ?? 'Không làm mới được'} Đang hiển thị số liệu lần tải trước.',
      ),
      actions: [
        TextButton(
          onPressed: () => context.read<PlatformOverviewCubit>().load(),
          child: const Text('Thử lại'),
        ),
      ],
    ),
  );
}
