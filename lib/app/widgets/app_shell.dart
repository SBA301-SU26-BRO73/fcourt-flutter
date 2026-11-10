import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../auth_redirect.dart';
import 'app_navigation.dart';

/// One persistent navigation surface for every signed-in destination.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    if (user == null ||
        publicRoutes.contains(location) ||
        location == AppRoutes.splash ||
        location == AppRoutes.resetPassword ||
        location == AppRoutes.offlineCheckIn ||
        location.startsWith('/profile') ||
        location == AppRoutes.settings ||
        location.startsWith('/notifications/') ||
        location.startsWith('/branches/') ||
        location.startsWith('/courts/') ||
        location.startsWith('/booking/') ||
        location.startsWith('/bookings/') ||
        location.startsWith('/payments/') && location != '/payments/history') {
      return child;
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selected = location == '/activity'
        ? 2
        : location.startsWith('/notifications')
        ? 3
        : location.startsWith('/bookings') ||
              location.startsWith('/payments') ||
              location.startsWith('/admin/bookings') ||
              location.startsWith('/staff/schedule') ||
              location == AppRoutes.superAdminOverview
        ? 1
        : 0;
    return Material(
      type: MaterialType.transparency,
      child: GlassScaffold(
        background: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [Color(0xFF102637), Color(0xFF142B34)]
                  : const [Colors.white, Colors.white],
            ),
          ),
        ),
        appBarHeight: 0,
        // Content stops above the floating glass bar so cards, prices and actions
        // never sit underneath (and collide with) the tab labels.
        extendBody: false,
        edgeFade: false,
        bottomBarHeight: 96,
        bottomBar: AppNavigation(role: user.role, selectedIndex: selected),
        body: Theme(
          data: Theme.of(context)
              .copyWith(scaffoldBackgroundColor: Colors.transparent),
          child: child,
        ),
      ),
    );
  }
}
