import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../admin_dashboard/presentation/widgets/compact_currency.dart';
import '../../domain/entities/platform_overview.dart';
import '../bloc/platform_overview_cubit.dart';
import '../widgets/growth_line_chart.dart';
import '../../../../app/widgets/fc_widgets.dart';
import '../../../../app/widgets/wp3b_widgets.dart';

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
      body: SafeArea(
        child: Column(
          children: [
            _Topline(canPop: Navigator.of(context).canPop()),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    return BlocBuilder<PlatformOverviewCubit, PlatformOverviewState>(
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
                padding: const EdgeInsets.fromLTRB(20, 4, 20, Gap.navClearance),
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
                  const SizedBox(height: 12),
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
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.overview, required this.columns});

  final PlatformOverview overview;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final fc = context.fc;
    final cards = [
      KpiCard(
        key: const ValueKey('kpi-gmv'),
        icon: Icons.payments_outlined,
        tone: fc.success,
        label: 'Tổng GMV đặt sân',
        value: formatCompactVnd(overview.gmv),
        note: 'Doanh thu đặt sân qua hệ thống',
      ),
      KpiCard(
        key: const ValueKey('kpi-saas'),
        icon: Icons.workspace_premium_outlined,
        label: 'Doanh thu gói SaaS',
        value: formatCompactVnd(overview.saasRevenue),
        note: 'Chủ sân mua gói',
      ),
      KpiCard(
        key: const ValueKey('kpi-branches'),
        icon: Icons.store_mall_directory_outlined,
        tone: fc.info,
        label: 'Tổng chi nhánh',
        value: '${overview.branches.total}',
        note: '${overview.branches.active} hoạt động · ${overview.courts} sân',
      ),
      KpiCard(
        key: const ValueKey('kpi-customers'),
        icon: Icons.groups_outlined,
        tone: fc.warning,
        label: 'Khách hàng hoạt động',
        value: '${overview.customers.active}',
        note:
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
                    Expanded(
                      child: i < cards.length ? cards[i] : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
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
    return FcCard(
      key: const ValueKey('growth-card'),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tăng trưởng tài khoản và dòng tiền',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
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
    );
  }
}

class _TopOwnersCard extends StatelessWidget {
  const _TopOwnersCard({required this.owners});

  final List<TopOwner> owners;

  @override
  Widget build(BuildContext context) {
    return FcCard(
      key: const ValueKey('top-owners-card'),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top 5 chủ sân doanh thu cao nhất',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
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
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  foregroundColor: Theme.of(context)
                      .colorScheme
                      .onPrimaryContainer,
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

/// Mock-up topline: 58dp, optional round back button, 22px title and a round
/// refresh button.
class _Topline extends StatelessWidget {
  const _Topline({required this.canPop});
  final bool canPop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            if (canPop) ...[
              CircleIconButton(
                icon: Icons.chevron_left,
                tooltip: 'Quay lại',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                'Thống kê nền tảng',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.7,
                ),
              ),
            ),
            BlocBuilder<PlatformOverviewCubit, PlatformOverviewState>(
              builder: (context, state) => CircleIconButton(
                icon: Icons.refresh,
                tooltip: 'Tải lại',
                onPressed: state.status == PlatformOverviewStatus.loading
                    ? null
                    : () => context.read<PlatformOverviewCubit>().load(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
