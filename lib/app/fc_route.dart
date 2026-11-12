import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'widgets/app_backdrop.dart';

/// A [GoRoute] whose page carries the aurora wallpaper and a real transition.
///
/// Scaffolds are transparent, so every page must paint its own backdrop or
/// the page below would show through. Pushed pages use the platform
/// transition (which adds the backdrop through the theme); tab roots and the
/// entry screens cross-fade instead of sliding.
class FcRoute extends GoRoute {
  FcRoute({required super.path, super.name, GoRouterWidgetBuilder? builder})
    : super(
        pageBuilder: builder == null
            ? null
            : (context, state) => _fadeRoots.contains(state.matchedLocation)
                  ? CustomTransitionPage<void>(
                      key: state.pageKey,
                      name: state.name ?? state.path,
                      transitionDuration: const Duration(milliseconds: 220),
                      reverseTransitionDuration: const Duration(
                        milliseconds: 180,
                      ),
                      transitionsBuilder: (_, animation, _, child) =>
                          FadeTransition(
                            opacity: CurveTween(curve: Curves.easeOutCubic)
                                .animate(animation),
                            child: child,
                          ),
                      child: AppBackdrop(child: builder(context, state)),
                    )
                  : MaterialPage<void>(
                      key: state.pageKey,
                      name: state.name ?? state.path,
                      child: builder(context, state),
                    ),
      );

  static const _fadeRoots = {
    '/splash',
    '/login',
    '/home',
    '/discover',
    '/bookings',
    '/notifications',
    '/staff/schedule',
    '/admin/bookings',
    '/super-admin/overview',
  };
}
