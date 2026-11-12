import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../auth_redirect.dart';
import 'app_backdrop.dart';
import 'app_navigation.dart';
import '../../features/auth/domain/entities/user_role.dart';
import '../../features/notifications/domain/app_notification.dart';

/// One persistent navigation surface for every signed-in destination.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.location,
    required this.child,
    this.notificationsRepository,
  });
  final String location;
  final Widget child;
  final NotificationsRepository? notificationsRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late Future<int> _unreadCount;

  @override
  void initState() {
    super.initState();
    _unreadCount = _loadUnreadCount(widget.notificationsRepository);
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notificationsRepository != widget.notificationsRepository) {
      _unreadCount = _loadUnreadCount(widget.notificationsRepository);
    } else if (oldWidget.location != widget.location &&
        (oldWidget.location.startsWith('/notifications') ||
            widget.location.startsWith('/notifications'))) {
      _unreadCount = _loadUnreadCount(widget.notificationsRepository);
    }
  }

  Future<int> _loadUnreadCount(NotificationsRepository? repository) async {
    if (repository == null) return 0;
    try {
      return await repository.unreadCount();
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    if (user == null ||
        publicRoutes.contains(widget.location) ||
        widget.location == AppRoutes.splash ||
        widget.location == AppRoutes.resetPassword ||
        widget.location == AppRoutes.offlineCheckIn ||
        widget.location.startsWith('/profile') ||
        widget.location == AppRoutes.settings ||
        widget.location == '/lookup' ||
        widget.location.startsWith('/notifications/') ||
        widget.location.startsWith('/branches/') ||
        widget.location.startsWith('/courts/') ||
        widget.location.startsWith('/booking/') ||
        widget.location.startsWith('/bookings/') ||
        widget.location.startsWith('/payments/') &&
            widget.location != '/payments/history') {
      return widget.child;
    }
    final customer = user.role == UserRole.customer;
    final selected = widget.location == '/activity'
        ? 2
        : widget.location.startsWith('/notifications')
        ? 3
        : widget.location.startsWith('/bookings') ||
              widget.location.startsWith('/payments') ||
              widget.location.startsWith('/admin/bookings') ||
              widget.location.startsWith('/staff/schedule') ||
              widget.location == AppRoutes.superAdminOverview
        ? 1
        : 0;
    return Material(
      type: MaterialType.transparency,
      child: GlassScaffold(
        background: const AppBackdrop(),
        appBarHeight: 0,
        // Customer pages scroll underneath the floating glass pill (no opaque
        // strip around it); other roles keep the body above the bar so their
        // fixed action buttons stay clear.
        extendBody: customer,
        edgeFade: false,
        bottomBarHeight: 96,
        bottomBar: _navigation(user.role, selected),
        body: Theme(
          data: Theme.of(context),
          child: customer
              ? MediaQuery(
                  // Lists add this bottom padding so their last item can
                  // scroll clear of the pill.
                  data: MediaQuery.of(context).copyWith(
                    padding: MediaQuery.paddingOf(context)
                        .copyWith(bottom: floatingNavClearance(context)),
                  ),
                  child: widget.child,
                )
              : widget.child,
        ),
      ),
    );
  }

  Widget _navigation(UserRole role, int selected) {
    final repository = widget.notificationsRepository;
    if (repository == null) {
      return AppNavigation(role: role, selectedIndex: selected);
    }
    return FutureBuilder<int>(
      future: _unreadCount,
      builder: (context, snapshot) => AppNavigation(
        role: role,
        selectedIndex: selected,
        unreadCount: snapshot.data ?? 0,
      ),
    );
  }
}

/// Height of the floating tab pill plus the device's bottom inset: the space a
/// customer list must leave at its end so its last item is not hidden.
double floatingNavClearance(BuildContext context) =>
    96 + MediaQuery.viewPaddingOf(context).bottom;
