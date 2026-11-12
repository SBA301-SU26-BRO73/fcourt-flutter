import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../features/auth/domain/entities/user_role.dart';
import '../auth_redirect.dart';

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
    NavDestination('Khám phá', CupertinoIcons.compass, AppRoutes.discover),
    NavDestination('Đơn của tôi', CupertinoIcons.ticket, '/bookings'),
    NavDestination('Thông báo', CupertinoIcons.bell, '/notifications'),
    NavDestination('Tài khoản', CupertinoIcons.person, AppRoutes.profile),
  ],
  UserRole.admin => const [
    NavDestination(
      'Việc cần làm',
      CupertinoIcons.checkmark_seal,
      AppRoutes.home,
    ),
    NavDestination('Đơn', CupertinoIcons.ticket, '/admin/bookings'),
    NavDestination(
      'Chi nhánh',
      CupertinoIcons.building_2_fill,
      '/admin/branches',
    ),
    NavDestination('Tài khoản', CupertinoIcons.person, AppRoutes.profile),
  ],
  UserRole.staff => const [
    NavDestination('Tổng quan', CupertinoIcons.house, AppRoutes.home),
    NavDestination('Lịch sân', CupertinoIcons.calendar, '/staff/schedule'),
    NavDestination('Thông báo', CupertinoIcons.bell, '/notifications'),
    NavDestination('Tài khoản', CupertinoIcons.person, AppRoutes.profile),
  ],
  UserRole.superAdmin => const [
    NavDestination('Tổng quan', CupertinoIcons.house, AppRoutes.home),
    NavDestination(
      'Chủ sân',
      CupertinoIcons.person_2,
      '/super-admin/owners/pending',
    ),
    NavDestination('Thông báo', CupertinoIcons.bell, '/notifications'),
    NavDestination('Tài khoản', CupertinoIcons.person, AppRoutes.profile),
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
    final routes = [for (final d in destinations) d.route];
    final colors = Theme.of(context).colorScheme;
    final bar = GlassTabBar.bottom(
      key: const ValueKey('persistent-app-tabs'),
      selectedIndex: selectedIndex,
      onTabSelected: (index) {
        final destination = destinations[index];
        if (GoRouterState.of(context).uri.path == destination.route) return;
        // Tài khoản là màn con (có nút Back), không thay thế màn đang đứng.
        if (destination.route == AppRoutes.profile) {
          context.push(destination.route);
        } else {
          context.go(destination.route);
        }
      },
      horizontalPadding: 16,
      verticalPadding: 14,
      barHeight: 64,
      selectedIconColor: colors.primary,
      selectedLabelColor: colors.primary,
      unselectedIconColor: colors.onSurfaceVariant,
      unselectedLabelColor: colors.onSurfaceVariant,
      indicatorColor: colors.primary.withValues(alpha: .12),
      innerBlur: 8,
      // Frosted tint: enough white (navy in dark mode) that icons and labels
      // stay readable over cards, while content remains faintly visible.
      settings: LiquidGlassSettings(
        glassColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF102637).withValues(alpha: .62)
            : Colors.white.withValues(alpha: .62),
        blur: 12,
        thickness: 22,
        saturation: 1.2,
        lightIntensity: .6,
      ),
      indicatorSettings: LiquidGlassSettings.classicIndicator.copyWith(
        blur: 5,
        thickness: 26,
        refractiveIndex: 1.16,
        lightIntensity: .9,
        chromaticAberration: .01,
      ),
      tabs: [
        for (final d in destinations)
          GlassTab(
            icon: d.route == '/notifications'
                ? Badge(
                    isLabelVisible: unreadCount > 0,
                    smallSize: 8,
                    child: Icon(d.icon),
                  )
                : Icon(d.icon),
            label: d.label,
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = (constraints.maxWidth - 32) / routes.length;
        final reducedMotion = MediaQuery.disableAnimationsOf(context);
        return Stack(
          children: [
            bar,
            AnimatedPositioned(
              key: const ValueKey('active-tab-glass-ring'),
              duration: reducedMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              left: 18 + tabWidth * selectedIndex,
              bottom: MediaQuery.paddingOf(context).bottom + 18,
              width: tabWidth - 4,
              height: 56,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _GlassSelectionRing(
                      tint: colors.primary,
                      dark: Theme.of(context).brightness == Brightness.dark,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Optical rim for the resting lens; the package supplies the refractive lens
/// and spring interaction. This is paint only, with no extra glass/GPU layer.
class _GlassSelectionRing extends CustomPainter {
  const _GlassSelectionRing({required this.tint, required this.dark});
  final Color tint;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1.2);
    final shape = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = tint.withValues(alpha: dark ? .24 : .16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: dark ? .8 : 1),
            tint.withValues(alpha: dark ? .65 : .4),
            const Color(0xFF99BAF5).withValues(alpha: .7),
            Colors.white.withValues(alpha: .9),
          ],
          stops: const [0, .4, .72, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlassSelectionRing oldDelegate) =>
      oldDelegate.tint != tint || oldDelegate.dark != dark;
}
