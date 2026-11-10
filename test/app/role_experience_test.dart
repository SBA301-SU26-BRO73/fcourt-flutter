import 'package:fcourt/app/auth_redirect.dart';
import 'package:fcourt/app/theme/app_theme.dart';
import 'package:fcourt/app/theme/theme_controller.dart';
import 'package:fcourt/features/auth/domain/entities/auth_user.dart';
import 'package:fcourt/features/auth/domain/entities/user_role.dart';
import 'package:fcourt/features/auth/domain/usecases/logout.dart';
import 'package:fcourt/features/auth/domain/usecases/restore_session.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fcourt/features/auth/presentation/pages/home_page.dart';
import 'package:fcourt/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/auth/helpers.dart';

void main() {
  test(
    'customer booking routes reject other roles while settings stay shared',
    () {
      for (final role in UserRole.values) {
        for (final route in [
          '/discover',
          '/branches',
          '/branches/1',
          '/courts/1/slots',
          '/booking/summary',
          '/booking/confirm',
          '/bookings',
          '/payments/checkout',
        ]) {
          expect(
            authRedirect(AuthStatus.authenticated, route, role: role),
            role == UserRole.customer ? isNull : AppRoutes.home,
            reason: '${role.name}: $route',
          );
        }
        expect(
          authRedirect(
            AuthStatus.authenticated,
            AppRoutes.settings,
            role: role,
          ),
          isNull,
        );
      }
      expect(
        authRedirect(AuthStatus.unauthenticated, AppRoutes.settings),
        AppRoutes.login,
      );
    },
  );

  for (final role in UserRole.values) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        '${role.name} home and settings fit a small phone with large text in ${mode.name}',
        (tester) async {
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 1.6;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final auth =
              AuthBloc(
                RestoreSession(MockAuthRepository()),
                Logout(MockAuthRepository()),
              )..add(
                AuthSignedIn(
                  AuthUser(
                    id: 1,
                    email: 'qa@example.test',
                    fullName: 'Một người dùng có họ tên dài',
                    role: role,
                    status: 'ACTIVE',
                  ),
                ),
              );
          addTearDown(auth.close);
          final theme = ThemeController(
            read: () async => mode.name,
            write: (_) async {},
          );
          addTearDown(theme.dispose);
          await theme.restore();
          Widget app(Widget page) => BlocProvider.value(
            value: auth,
            child: ThemeScope(
              controller: theme,
              child: MaterialApp(
                theme: AppTheme.light(),
                darkTheme: AppTheme.dark(),
                themeMode: mode,
                home: page,
              ),
            ),
          );
          await tester.pumpWidget(app(const HomePage()));
          await tester.pump();
          expect(tester.takeException(), isNull);
          await tester.drag(
            find.byType(SingleChildScrollView).first,
            const Offset(0, -500),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(app(const SettingsPage()));
          await tester.pump();
          expect(find.text('Chế độ hiển thị'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('settings changes theme immediately and saves the preference', (
    tester,
  ) async {
    final writes = <String>[];
    final theme = ThemeController(write: (value) async => writes.add(value));
    addTearDown(theme.dispose);
    final auth = AuthBloc(
      RestoreSession(MockAuthRepository()),
      Logout(MockAuthRepository()),
    )..add(const AuthSignedIn(customerUser));
    addTearDown(auth.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: auth,
        child: ThemeScope(
          controller: theme,
          child: ListenableBuilder(
            listenable: theme,
            builder: (_, _) => MaterialApp(
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: theme.mode,
              home: const SettingsPage(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Tối'));
    await tester.tap(find.text('Tối'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Chế độ hiển thị'))).brightness,
      Brightness.dark,
    );
    expect(writes, ['dark']);
  });
}
