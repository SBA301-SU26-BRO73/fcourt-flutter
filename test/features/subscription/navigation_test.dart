import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fcourt/app/app_dependencies.dart';
import 'package:fcourt/app/router.dart';
import 'package:fcourt/app/auth_redirect.dart';
import 'package:fcourt/core/config/app_config.dart';
import 'package:fcourt/features/auth/domain/entities/user_role.dart';
import 'package:fcourt/features/auth/domain/usecases/logout.dart';
import 'package:fcourt/features/auth/domain/usecases/restore_session.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fcourt/features/health/domain/repositories/health_repository.dart';
import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';

import '../auth/helpers.dart';
import '../catalog/helpers.dart';
import 'fixtures.dart';

class HealthMock extends Mock implements HealthRepository {}

class DiscoveryMock extends Mock implements DiscoveryRepository {}

void main() {
  test('subscription route only permits signed-in court admin', () {
    for (final role in UserRole.values) {
      expect(
        authRedirect(
          AuthStatus.authenticated,
          '/admin/subscription',
          role: role,
        ),
        role == UserRole.admin ? isNull : AppRoutes.home,
      );
    }
    expect(
      authRedirect(AuthStatus.unauthenticated, '/admin/subscription'),
      AppRoutes.login,
    );
  });
  testWidgets(
    'admin home opens actual subscription route; customer cannot fetch private billing',
    (tester) async {
      for (final user in [adminUser, customerUser]) {
        final auth = AuthBloc(
          RestoreSession(MockAuthRepository()),
          Logout(MockAuthRepository()),
        )..add(AuthSignedIn(user));
        addTearDown(auth.close);
        final refresh = AuthRefreshNotifier(auth.stream);
        final billing = Billing();
        final router = createRouter(
          AppDependencies(
            config: const AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://test'),
            healthRepository: HealthMock(),
            authRepository: MockAuthRepository(),
            catalogRepository: MockCatalogRepository(),
            discoveryRepository: DiscoveryMock(),
            subscriptions: billing,
            subscriptionCheckoutLauncher: CheckoutLauncher(),
          ),
          auth,
          refreshListenable: refresh,
        );
        await tester.pumpWidget(
          BlocProvider.value(
            value: auth,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        if (user.role == UserRole.admin) {
          await tester.ensureVisible(find.text('Gói dịch vụ'));
          await tester.tap(find.text('Gói dịch vụ'));
          await tester.pumpAndSettle();
          expect(find.text('Gói hiện tại'), findsOneWidget);
          expect(billing.calls, contains('current'));
        } else {
          router.go('/admin/subscription');
          await tester.pumpAndSettle();
          expect(find.text('Gói hiện tại'), findsNothing);
          expect(billing.calls, isEmpty);
        }
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        refresh.dispose();
      }
    },
  );
}
