import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/auth_redirect.dart';
import '../../../../app/widgets/fc_widgets.dart';
import '../../../../src/features/customer_discovery/domain/discovery_repository.dart';
import '../../../../src/features/customer_discovery/presentation/widgets/venue_feed.dart';
import '../../../../src/features/customer_discovery/presentation/widgets/discovery_widgets.dart';
import '../../domain/entities/user_role.dart';
import '../bloc/auth_bloc.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, this.discoveryRepository, this.adminTodo});
  final DiscoveryRepository? discoveryRepository;

  /// Khối "Việc cần làm" của chủ sân; thay cho banner chào ở đầu trang chủ.
  final Widget? adminTodo;

  static String titleFor(UserRole role) => switch (role) {
    UserRole.customer => 'Đặt sân',
    UserRole.staff => 'Vận hành chi nhánh',
    UserRole.admin => 'Quản lý cụm sân',
    UserRole.superAdmin => 'Quản trị hệ thống',
  };

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    if (user == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final entries = _entries(user.role);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(titleFor(user.role)),
        actions: [
          IconButton(
            tooltip: 'Cài đặt',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
          IconButton(
            tooltip: 'Tài khoản',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push(AppRoutes.profile),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                Gap.screen,
                Gap.sm,
                Gap.screen,
                Gap.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: colors.primaryContainer,
                        foregroundColor: colors.onPrimaryContainer,
                        child: Text(
                          user.displayName.trim().isEmpty
                              ? 'F'
                              : user.displayName.trim()[0].toUpperCase(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Xin chào, ${user.displayName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              user.role.label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.xl),
                  if (user.role == UserRole.admin && adminTodo != null) ...[
                    adminTodo!,
                    const SizedBox(height: Gap.xl),
                  ],
                  if (user.role == UserRole.customer) ...[
                    TextField(
                      maxLength: 200,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (query) => context.push(
                        Uri(
                          path: '/branches',
                          queryParameters: {'query': query.trim()},
                        ).toString(),
                      ),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        labelText: 'Bạn muốn chơi ở đâu?',
                        hintText: 'Tên sân hoặc địa chỉ',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: Gap.xxl),
                    const SectionHeader('Khám phá theo môn'),
                    const SizedBox(height: Gap.md),
                    if (discoveryRepository != null)
                      VenueFeed(repository: discoveryRepository!)
                    else
                      SportFilters(
                        onSelected: (sport) => context.push(
                          Uri(
                            path: '/branches',
                            queryParameters: {
                              if (sport != null) 'sport': sport.name,
                            },
                          ).toString(),
                        ),
                      ),
                    const SizedBox(height: Gap.xxl),
                  ],
                  if (user.role == UserRole.customer)
                    const SectionHeader('Của tôi'),
                  if (user.role == UserRole.customer)
                    const SizedBox(height: Gap.md),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 720
                          ? 3
                          : constraints.maxWidth >= 440
                          ? 2
                          : 1;
                      final width =
                          (constraints.maxWidth - (columns - 1) * Gap.md) /
                          columns;
                      return Wrap(
                        spacing: Gap.md,
                        runSpacing: Gap.md,
                        children: [
                          for (final entry in entries)
                            SizedBox(
                              width: width,
                              child: _ActionCard(entry: entry),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Entry {
  const _Entry(this.title, this.icon, this.route);
  final String title, route;
  final IconData icon;
  Key? get key => route == '/super-admin/overview'
      ? const ValueKey('home-super-admin-overview')
      : null;
}

List<_Entry> _entries(UserRole role) => switch (role) {
  UserRole.customer => const [
    _Entry('Tìm sân', Icons.search, '/discover'),
    _Entry('Lịch sử đặt sân', Icons.confirmation_number_outlined, '/bookings'),
    _Entry('Lịch sử giao dịch', Icons.receipt_long_outlined, '/payments/history'),
  ],
  UserRole.staff => const [
    _Entry('Lịch hôm nay', Icons.calendar_today_outlined, '/staff/schedule'),
    _Entry('Bán lẻ (POS)', Icons.point_of_sale_outlined, '/staff/pos'),
  ],
  UserRole.admin => const [
    _Entry('Tổng quan', Icons.dashboard_outlined, '/admin/dashboard'),
    _Entry('Quản lý đơn đặt sân', Icons.event_note_outlined, '/admin/bookings'),
    _Entry('Chi nhánh và sân', Icons.account_tree_outlined, '/admin/branches'),
    _Entry('Phân tích', Icons.analytics_outlined, '/admin/analytics'),
    _Entry('Nhân viên', Icons.badge_outlined, '/admin/staff'),
    _Entry('Gói dịch vụ', Icons.workspace_premium_outlined, '/admin/subscription'),
    _Entry('Quản lý voucher', Icons.local_offer_outlined, '/admin/vouchers'),
  ],
  UserRole.superAdmin => const [
    _Entry('Thống kê nền tảng', Icons.insights_outlined, '/super-admin/overview'),
    _Entry('Chủ sân chờ duyệt', Icons.pending_actions_outlined, '/super-admin/owners/pending'),
    _Entry('Quản lý danh mục', Icons.category_outlined, '/catalog'),
  ],
};

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.entry});
  final _Entry entry;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // A real button (not a bare card) so it is announced and focusable as one.
    return OutlinedButton(
      key: entry.key,
      style: OutlinedButton.styleFrom(
        backgroundColor: colors.surfaceContainerLow,
        foregroundColor: colors.onSurface,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.md,
        ),
        side: BorderSide(color: colors.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
      ),
      onPressed: () => context.push(entry.route),
      child: Row(
        children: [
          IconBadge(entry.icon),
          const SizedBox(width: Gap.md),
          Expanded(child: Text(entry.title, style: theme.textTheme.titleSmall)),
          Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
        ],
      ),
    );
  }
}
