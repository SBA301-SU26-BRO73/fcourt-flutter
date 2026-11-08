import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/domain/usecases/logout.dart';
import '../features/auth/domain/usecases/restore_session.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/domain/entities/user_role.dart';
import '../features/offline/data/offline_access.dart';
import 'app_dependencies.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class FcourtApp extends StatefulWidget {
  const FcourtApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<FcourtApp> createState() => _FcourtAppState();
}

class _FcourtAppState extends State<FcourtApp> {
  late final AuthBloc _authBloc;
  late final AuthRefreshNotifier _refresh;
  late final GoRouter _router;
  late final StreamSubscription<void> _sessionExpired;
  late final StreamSubscription<AuthState> _offlineLifecycle;

  @override
  void initState() {
    super.initState();
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
    unawaited(widget.dependencies.offline?.close());
    _refresh.dispose();
    _router.dispose();
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: MaterialApp.router(
        title: 'FCOURT',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: _router,
      ),
    );
  }
}
