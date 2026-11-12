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
    final fc = context.fc;
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                Gap.screen,
                Gap.sm,
                Gap.screen,
                Gap.screen,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: fc.brand,
                          border: Border.all(color: fc.hairline, width: 2),
                          boxShadow: fc.shadowSmall,
                        ),
                        child: Text(
                          user.displayName.trim().isEmpty
                              ? 'F'
                              : user.displayName.trim()[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
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
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.role.label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      StatusPill('FCOURT', color: colors.primary),
                    ],
                  ),
                  const SizedBox(height: Gap.xl),
                  if (user.role == UserRole.admin && adminTodo != null) ...[
                    adminTodo!,
                    const SizedBox(height: Gap.xl),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: HeroPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Eyebrow(
                              user.role == UserRole.customer
                                  ? 'SẴN SÀNG CHO TRẬN ĐẤU TIẾP THEO'
                                  : 'KHÔNG GIAN LÀM VIỆC CỦA BẠN',
                              icon: Icons.bolt_rounded,
                              color: fc.onBrandMuted,
                            ),
                            const SizedBox(height: Gap.lg),
                            Text(
                              switch (user.role) {
                                UserRole.customer => 'Ra sân. Hết mình.',
                                UserRole.staff => 'Sẵn sàng cho ca làm mới.',
                                UserRole.admin => 'Quản lý sân, dễ dàng hơn.',
                                UserRole.superAdmin =>
                                  'Kết nối toàn bộ hệ thống.',
                              },
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: Gap.md),
                            Text(
                              switch (user.role) {
                                UserRole.customer => 'Khám phá sân phù hợp, chọn giờ yêu thích và đặt lịch cho buổi chơi của bạn.',
                                UserRole.staff => 'Theo dõi lịch sân, nhận khách và xử lý đơn bán lẻ tại một nơi.',
                                UserRole.admin => 'Theo dõi hoạt động, quản lý đơn đặt và phát triển cụm sân của bạn.',
                                UserRole.superAdmin => 'Duyệt chủ sân, quản lý danh mục và theo dõi số liệu nền tảng.',
                              },
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: fc.onBrandMuted,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: Gap.screen),
                            FilledButton.icon(
                              key: user.role == UserRole.superAdmin
                                  ? const ValueKey('home-super-admin-overview')
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF06443F),
                              ),
                              onPressed: () =>
                                  context.push(entries.first.route),
                              icon: Icon(entries.first.icon),
                              label: Text(entries.first.title),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                  SectionHeader(
                    user.role == UserRole.customer
                        ? 'Buổi chơi của bạn'
                        : 'Quản lý công việc',
                    subtitle: user.role == UserRole.customer
                        ? 'Đặt lịch, ra sân và tận hưởng trận đấu.'
                        : 'Mọi công việc trong một không gian.',
                  ),
                  const SizedBox(height: Gap.lg),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 720
                          ? 3
                          : constraints.maxWidth >= 440
                          ? 2
                          : 1;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 12) / columns;
                      final tints = [
                        colors.primary,
                        colors.secondary,
                        colors.tertiary,
                        fc.warning,
                        fc.success,
                        fc.info,
                      ];
                      final rest = entries.skip(1).toList();
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final (index, entry) in rest.indexed)
                            SizedBox(
                              width: width,
                              child: _ActionCard(
                                entry: entry,
                                tint: tints[index % tints.length],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 128),
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
  const _Entry(this.title, this.subtitle, this.icon, this.route);
  final String title, subtitle, route;
  final IconData icon;
}

List<_Entry> _entries(UserRole role) => switch (role) {
  UserRole.customer => const [
    _Entry(
      'Tìm sân',
      'Khám phá chi nhánh và khung giờ',
      Icons.search,
      '/discover',
    ),
    _Entry(
      'Lịch sử đặt sân',
      'Xem lịch hẹn, vé và trạng thái đặt sân',
      Icons.confirmation_number_outlined,
      '/bookings',
    ),
    _Entry(
      'Lịch sử giao dịch',
      'Theo dõi thanh toán và hoàn tiền',
      Icons.receipt_long_outlined,
      '/payments/history',
    ),
  ],
  UserRole.staff => const [
    _Entry(
      'Lịch hôm nay',
      'Lịch sân, đặt tại quầy và nhận khách',
      Icons.calendar_today_outlined,
      '/staff/schedule',
    ),
    _Entry(
      'Bán lẻ (POS)',
      'Sản phẩm, giỏ hàng và hóa đơn',
      Icons.point_of_sale_outlined,
      '/staff/pos',
    ),
  ],
  UserRole.admin => const [
    _Entry(
      'Tổng quan',
      'Nắm bắt hoạt động kinh doanh',
      Icons.dashboard_outlined,
      '/admin/dashboard',
    ),
    _Entry(
      'Quản lý đơn đặt sân',
      'Tra cứu, theo dõi và xử lý đơn đặt',
      Icons.event_note_outlined,
      '/admin/bookings',
    ),
    _Entry(
      'Chi nhánh và sân',
      'Sân, bảng giá và khung giờ hoạt động',
      Icons.account_tree_outlined,
      '/admin/branches',
    ),
    _Entry(
      'Phân tích',
      'Doanh thu và hiệu quả khai thác sân',
      Icons.analytics_outlined,
      '/admin/analytics',
    ),
    _Entry(
      'Nhân viên',
      'Tài khoản và phân công chi nhánh',
      Icons.badge_outlined,
      '/admin/staff',
    ),
    _Entry(
      'Gói dịch vụ',
      'Quyền lợi, thời hạn và nâng cấp gói',
      Icons.workspace_premium_outlined,
      '/admin/subscription',
    ),
    _Entry(
      'Quản lý voucher',
      'Ưu đãi và lịch sử sử dụng mã',
      Icons.local_offer_outlined,
      '/admin/vouchers',
    ),
  ],
  UserRole.superAdmin => const [
    _Entry(
      'Thống kê nền tảng',
      'Theo dõi hoạt động toàn hệ thống',
      Icons.insights_outlined,
      '/super-admin/overview',
    ),
    _Entry(
      'Chủ sân chờ duyệt',
      'Kiểm tra hồ sơ và xét duyệt chủ sân',
      Icons.pending_actions_outlined,
      '/super-admin/owners/pending',
    ),
    _Entry(
      'Quản lý danh mục',
      'Loại sân và các gói dịch vụ',
      Icons.category_outlined,
      '/catalog',
    ),
  ],
};

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.entry, required this.tint});
  final _Entry entry;
  final Color tint;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fc = context.fc;
    // A real button (not a bare card) so it is announced and focusable as one.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.card),
        boxShadow: fc.shadow,
      ),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: fc.frostedFill,
          foregroundColor: colors.onSurface,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(Gap.lg),
          side: BorderSide(color: fc.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.card),
          ),
        ),
        onPressed: () => context.push(entry.route),
        child: Row(
          children: [
            IconBadge(entry.icon, color: tint),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    entry.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
