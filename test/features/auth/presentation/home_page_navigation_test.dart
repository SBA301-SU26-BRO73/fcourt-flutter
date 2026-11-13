import 'package:fcourt/features/auth/domain/entities/auth_user.dart';
import 'package:fcourt/features/auth/domain/entities/user_role.dart';
import 'package:fcourt/features/auth/domain/usecases/logout.dart';
import 'package:fcourt/features/auth/domain/usecases/restore_session.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fcourt/features/auth/presentation/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers.dart';

void main() {
  final destinations = <UserRole, Map<String, String>>{
    UserRole.customer: {
      'Tìm sân': '/discover',
      'Lịch sử đặt sân': '/bookings',
      'Lịch sử giao dịch': '/payments/history',
    },
    UserRole.staff: {
      'Lịch hôm nay': '/staff/schedule',
      'Bán lẻ (POS)': '/staff/pos',
    },
    UserRole.admin: {
      'Tổng quan': '/admin/dashboard',
      'Chi nhánh và sân': '/admin/branches',
      'Phân tích': '/admin/analytics',
      'Nhân viên': '/admin/staff',
      'Gói dịch vụ': '/admin/subscription',
      'Quản lý đơn đặt sân': '/admin/bookings',
      'Quản lý voucher': '/admin/vouchers',
    },
    UserRole.superAdmin: {
      'Chủ sân chờ duyệt': '/super-admin/owners/pending',
      'Quản lý danh mục': '/catalog',
      'Thống kê nền tảng': '/super-admin/overview',
    },
  };

  AuthUser userFor(UserRole role) => AuthUser(
    id: 1,
    email: 'test@example.com',
    role: role,
    status: 'ACTIVE',
    fullName: 'Test User',
  );

  Future<(AuthBloc, GoRouter)> setup(WidgetTester tester, UserRole role) async {
    final repository = MockAuthRepository();
    final authBloc = AuthBloc(RestoreSession(repository), Logout(repository))
      ..add(AuthSignedIn(userFor(role)));
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomePage()),
        for (final path
            in destinations.values.expand((map) => map.values).toSet())
          GoRoute(
            path: path,
            builder: (_, _) => Scaffold(body: Text(path)),
          ),
      ],
    );
    await tester.pumpWidget(
      BlocProvider.value(
        value: authBloc,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    return (authBloc, router);
  }

  for (final entry in destinations.entries) {
    testWidgets('${entry.key.name} sees only its home entries', (tester) async {
      final (authBloc, router) = await setup(tester, entry.key);
      addTearDown(authBloc.close);
      addTearDown(router.dispose);

      for (final labels in destinations.entries) {
        for (final label in labels.value.keys) {
          expect(
            find.descendant(
              of: find.bySubtype<ButtonStyleButton>(),
              matching: find.text(label),
            ),
            labels.key == entry.key ? findsOneWidget : findsNothing,
          );
        }
      }
    });

    for (final destination in entry.value.entries) {
      testWidgets(
        '${entry.key.name} ${destination.key} opens ${destination.value}',
        (tester) async {
          final (authBloc, router) = await setup(tester, entry.key);
          addTearDown(authBloc.close);
          addTearDown(router.dispose);

          await tester.ensureVisible(find.text(destination.key));
          await tester.tap(find.text(destination.key));
          await tester.pumpAndSettle();
          expect(find.text(destination.value), findsOneWidget);
        },
      );
    }
  }

  testWidgets(
    'home content does not overflow at larger text scale on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (authBloc, router) = await setup(tester, UserRole.admin);
      addTearDown(authBloc.close);
      addTearDown(router.dispose);

      expect(tester.takeException(), isNull);
      expect(find.text('Quản lý voucher'), findsOneWidget);
    },
  );
}
