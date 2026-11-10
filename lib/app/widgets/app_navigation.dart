import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../features/auth/domain/entities/user_role.dart';
import '../auth_redirect.dart';

class AppNavigation extends StatelessWidget {
  const AppNavigation({super.key, required this.role, this.selectedIndex = 0});
  final UserRole role;
  final int selectedIndex;
  @override
  Widget build(BuildContext context) {
    final customer = role == UserRole.customer;
    final mainRoute = switch (role) {
      UserRole.customer => AppRoutes.discover,
      UserRole.staff => '/staff/schedule',
      UserRole.admin => '/admin/bookings',
      UserRole.superAdmin => AppRoutes.superAdminOverview,
    };
    final routes = [
      customer ? AppRoutes.discover : AppRoutes.home,
      customer ? '/bookings' : mainRoute,
      '/activity',
      '/notifications',
    ];
    final colors = Theme.of(context).colorScheme;
    final bar = GlassTabBar.bottom(
      key: const ValueKey('persistent-app-tabs'),
      selectedIndex: selectedIndex,
      onTabSelected: (index) {
        if (GoRouterState.of(context).uri.path != routes[index]) {
          context.go(routes[index]);
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
      indicatorSettings: LiquidGlassSettings.classicIndicator.copyWith(
        blur: 5,
        thickness: 26,
        refractiveIndex: 1.16,
        lightIntensity: .9,
        chromaticAberration: .01,
      ),
      tabs: [
        GlassTab(
          icon: const Icon(CupertinoIcons.compass),
          label: customer ? 'Khám phá' : 'Tổng quan',
        ),
        GlassTab(
          icon: const Icon(CupertinoIcons.ticket),
          label: customer ? 'Đã đặt' : 'Vận hành',
        ),
        const GlassTab(icon: Icon(CupertinoIcons.clock), label: 'Hoạt động'),
        const GlassTab(icon: Icon(CupertinoIcons.bell), label: 'Thông báo'),
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
