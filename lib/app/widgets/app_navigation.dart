import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/entities/user_role.dart';
import '../auth_redirect.dart';
import 'floating_nav_bar.dart';

/// Một tab của thanh điều hướng dưới.
class NavDestination {
  const NavDestination(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}

/// Mỗi vai trò có 4 tab đúng việc của vai trò đó (không có tab rỗng).
List<NavDestination> navDestinations(UserRole role) => switch (role) {
  UserRole.customer => const [
    NavDestination('Khám phá', Icons.explore_outlined, AppRoutes.discover),
    NavDestination(
      'Đơn của tôi',
      Icons.confirmation_number_outlined,
      '/bookings',
    ),
    NavDestination('Thông báo', Icons.notifications_outlined, '/notifications'),
    NavDestination('Tài khoản', Icons.person_outline, AppRoutes.profile),
  ],
  UserRole.admin => const [
    NavDestination('Việc cần làm', Icons.task_alt_outlined, AppRoutes.home),
    NavDestination('Đơn', Icons.receipt_long_outlined, '/admin/bookings'),
    NavDestination('Chi nhánh', Icons.storefront_outlined, '/admin/branches'),
    NavDestination('Tài khoản', Icons.person_outline, AppRoutes.profile),
  ],
  UserRole.staff => const [
    NavDestination('Tổng quan', Icons.home_outlined, AppRoutes.home),
    NavDestination(
      'Lịch sân',
      Icons.calendar_today_outlined,
      '/staff/schedule',
    ),
    NavDestination('Thông báo', Icons.notifications_outlined, '/notifications'),
    NavDestination('Tài khoản', Icons.person_outline, AppRoutes.profile),
  ],
  UserRole.superAdmin => const [
    NavDestination('Tổng quan', Icons.home_outlined, AppRoutes.home),
    NavDestination(
      'Chủ sân',
      Icons.groups_outlined,
      '/super-admin/owners/pending',
    ),
    NavDestination('Thông báo', Icons.notifications_outlined, '/notifications'),
    NavDestination('Tài khoản', Icons.person_outline, AppRoutes.profile),
  ],
};

/// Tab đang sáng theo đường dẫn hiện tại; trang con của một mục giữ mục đó sáng.
int navSelectedIndex(UserRole role, String location) {
  final destinations = navDestinations(role);
  for (var i = 0; i < destinations.length; i++) {
    final route = destinations[i].route;
    if (route == AppRoutes.profile) continue;
    if (location == route || location.startsWith('$route/')) return i;
  }
  if (role == UserRole.customer && location.startsWith('/payments')) return 1;
  if (role == UserRole.admin && location.startsWith('/admin/bookings')) {
    return 1;
  }
  return 0;
}

/// Thanh điều hướng nổi bo tròn (FloatingNavBar), mỗi tab một icon outlined và nhãn.
class AppNavigation extends StatelessWidget {
  const AppNavigation({
    super.key,
    required this.role,
    this.selectedIndex = 0,
    this.unreadCount = 0,
  });
  final UserRole role;
  final int selectedIndex;
  final int unreadCount;
  @override
  Widget build(BuildContext context) {
    final destinations = navDestinations(role);
    return FloatingNavBar(
      key: const ValueKey('persistent-app-tabs'),
      selectedIndex: selectedIndex,
      items: [
        for (final d in destinations)
          FloatingNavItem(
            label: d.label,
            icon: d.icon,
            badgeCount: d.route == '/notifications' ? unreadCount : 0,
          ),
      ],
      onSelected: (index) {
        final destination = destinations[index];
        if (GoRouterState.of(context).uri.path == destination.route) return;
        // Tài khoản là màn con (có nút Back), không thay thế màn đang đứng.
        if (destination.route == AppRoutes.profile) {
          context.push(destination.route);
        } else {
          context.go(destination.route);
        }
      },
    );
  }
}
