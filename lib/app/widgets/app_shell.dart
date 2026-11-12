import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../auth_redirect.dart';
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
    final selected = navSelectedIndex(user.role, widget.location);
    // Floating bar: the body ends above it (FloatingNavBar.outerHeight), so
    // lists and floating action buttons never sit behind the navigation.
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: _navigation(user.role, selected),
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
