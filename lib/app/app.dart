import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/domain/usecases/logout.dart';
import '../features/auth/domain/usecases/restore_session.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/domain/entities/user_role.dart';
import '../features/offline/data/offline_access.dart';
import '../features/notifications/data/push_service.dart';
import '../features/notifications/domain/push_payload.dart';
import '../features/notifications/domain/push_session_coordinator.dart';
import 'app_dependencies.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class FcourtApp extends StatefulWidget {
  const FcourtApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<FcourtApp> createState() => _FcourtAppState();
}

class _FcourtAppState extends State<FcourtApp> {
  final _theme = ThemeController();
  late final AuthBloc _authBloc;
  late final AuthRefreshNotifier _refresh;
  late final GoRouter _router;
  late final StreamSubscription<void> _sessionExpired;
  late final StreamSubscription<AuthState> _offlineLifecycle;
  late final StreamSubscription<AuthState>? _pushLifecycle;
  late final StreamSubscription<PushPayload>? _pushPayloads;

  @override
  void initState() {
    super.initState();
    unawaited(_theme.restore());
    final repository = widget.dependencies.authRepository;
    _authBloc = AuthBloc(
      RestoreSession(repository),
      Logout(repository),
      restoreOfflineStaff: widget.dependencies.offline == null
          ? null
          : OfflineAccess(widget.dependencies.offline!.coordinator).restore,
    )..add(const AuthStarted());
    _refresh = AuthRefreshNotifier(_authBloc.stream);
    _router = createRouter(
      widget.dependencies,
      _authBloc,
      refreshListenable: _refresh,
    );
    final pushService = widget.dependencies.pushService;
    final pushCoordinator = widget.dependencies.pushSessionCoordinator;
    if (pushService != null && pushCoordinator != null) {
      _pushLifecycle = _authBloc.stream.listen((state) {
        pushCoordinator.onAuthenticationChanged(
          state.status == AuthStatus.authenticated,
        );
      });
      pushCoordinator.onAuthenticationChanged(
        _authBloc.state.status == AuthStatus.authenticated,
      );
      _pushPayloads = pushService.payloads.listen((payload) {
        final route = payload.route;
        if (route != null && route.startsWith('/')) _router.go(route);
      });
      unawaited(_initializePush(pushService, pushCoordinator));
    } else {
      _pushLifecycle = null;
      _pushPayloads = null;
    }
    _sessionExpired = widget.dependencies.sessionExpired.listen(
      (_) => _authBloc.add(const AuthSessionExpired()),
    );
    _offlineLifecycle = _authBloc.stream.listen((state) {
      if (state.status == AuthStatus.unauthenticated ||
          (state.status == AuthStatus.authenticated &&
              state.role != UserRole.staff)) {
        widget.dependencies.offline?.pause();
      }
    });
  }

  @override
  void dispose() {
    _sessionExpired.cancel();
    _offlineLifecycle.cancel();
    _pushLifecycle?.cancel();
    _pushPayloads?.cancel();
    unawaited(widget.dependencies.pushService?.dispose());
    unawaited(widget.dependencies.offline?.close());
    _theme.dispose();
    _refresh.dispose();
    _router.dispose();
    _authBloc.close();
    super.dispose();
  }

  Future<void> _initializePush(
    PushService service,
    PushSessionCoordinator coordinator,
  ) async {
    try {
      await service.initialize(coordinator);
    } catch (_) {
      // Lỗi khởi tạo push không được ngăn app mở.
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: ThemeScope(
        controller: _theme,
        child: ListenableBuilder(
          listenable: _theme,
          builder: (context, _) => MaterialApp.router(
            builder: (context, child) => LiquidGlassWidgets.wrap(
              adaptiveQuality: true,
              respectSystemAccessibility: true,
              brightnessResolver: Theme.maybeBrightnessOf,
              theme: const GlassThemeData.ios26(),
              child: child ?? const SizedBox.shrink(),
            ),
            title: 'FCOURT',
            themeMode: _theme.mode,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            routerConfig: _router,
          ),
        ),
      ),
    );
  }
}
