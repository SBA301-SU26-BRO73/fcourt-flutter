import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/auth_redirect.dart';
import '../../domain/entities/user_role.dart';
import '../bloc/auth_bloc.dart';

/// Trang chủ tạm theo vai trò. Mỗi vai trò sẽ được thay bằng màn hình thật khi feature
/// tương ứng hoàn thành.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
    return Scaffold(
      appBar: AppBar(
        title: Text(titleFor(user.role)),
        actions: [
          IconButton(
            tooltip: 'Tài khoản',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push(AppRoutes.profile),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Xin chào, ${user.displayName}',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(user.role.label),
          if (user.role == UserRole.admin) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/admin/dashboard'),
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('Tổng quan'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push('/admin/branches'),
              icon: const Icon(Icons.account_tree_outlined),
              label: const Text('Chi nhánh và sân'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push('/admin/analytics'),
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Phân tích'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.staff),
              icon: const Icon(Icons.badge_outlined),
              label: const Text('Nhân viên'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push('/admin/subscription'),
              icon: const Icon(Icons.workspace_premium_outlined),
              label: const Text('Gói dịch vụ'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push('/admin/bookings'),
              icon: const Icon(Icons.event_note),
              label: const Text('Quản lý đơn đặt sân'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push('/admin/vouchers'),
              icon: const Icon(Icons.local_offer_outlined),
              label: const Text('Quản lý voucher'),
            ),
          ],
          if (user.role == UserRole.staff) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/staff/schedule'),
              icon: const Icon(Icons.calendar_today_outlined),
              label: const Text('Lịch hôm nay'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push('/staff/pos'),
              icon: const Icon(Icons.point_of_sale_outlined),
              label: const Text('Bán lẻ (POS)'),
            ),
          ],
          if (user.role == UserRole.superAdmin) ...[
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: () => context.push('/super-admin/owners/pending'),
              icon: const Icon(Icons.pending_actions_outlined),
              label: const Text('Chủ sân chờ duyệt'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => context.push(AppRoutes.catalog),
              icon: const Icon(Icons.category_outlined),
              label: const Text('Quản lý danh mục'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const ValueKey('home-super-admin-overview'),
              onPressed: () => context.push(AppRoutes.superAdminOverview),
              icon: const Icon(Icons.insights_outlined),
              label: const Text('Thống kê nền tảng'),
            ),
          ],
          if (user.role == UserRole.customer) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.discover),
              icon: const Icon(Icons.search),
              label: const Text('Tìm sân'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/bookings'),
              icon: const Icon(Icons.history),
              label: const Text('Lịch sử đặt sân'),
            ),
          ],
        ],
      ),
    );
  }
}
