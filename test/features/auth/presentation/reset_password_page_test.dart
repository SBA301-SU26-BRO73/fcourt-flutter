import 'package:fcourt/app/auth_redirect.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/auth/domain/usecases/logout.dart';
import 'package:fcourt/features/auth/domain/usecases/reset_password.dart';
import 'package:fcourt/features/auth/domain/usecases/restore_session.dart';
import 'package:fcourt/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fcourt/features/auth/presentation/bloc/reset_password_bloc.dart';
import 'package:fcourt/features/auth/presentation/pages/reset_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  late MockAuthRepository repository;
  late AuthBloc authBloc;

  setUp(() {
    repository = MockAuthRepository();
    authBloc = AuthBloc(RestoreSession(repository), Logout(repository));
  });

  tearDown(() => authBloc.close());

  Future<void> pumpPage(WidgetTester tester, {String? token}) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: authBloc),
              BlocProvider(create: (_) => ResetPasswordBloc(ResetPassword(repository))),
            ],
            child: ResetPasswordPage(initialToken: token),
          ),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const Scaffold(body: Text('Màn đăng nhập')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> fillPasswords(WidgetTester tester, {String confirm = 'new-pass-2'}) async {
    await tester.enterText(field('Mật khẩu mới'), 'new-pass-2');
    await tester.enterText(field('Nhập lại mật khẩu mới'), confirm);
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Đặt lại mật khẩu'));
    await tester.pump();
  }

  When<Future<void>> stubReset() => when(
        () => repository.resetPassword(
          token: any(named: 'token'),
          newPassword: any(named: 'newPassword'),
        ),
      );

  testWidgets('mở từ link thì token được điền sẵn', (tester) async {
    await pumpPage(tester, token: 'abc123');

    expect(tester.widget<TextFormField>(field('Mã đặt lại mật khẩu')).controller?.text, 'abc123');
  });

  testWidgets('thiếu token hoặc mật khẩu nhập lại không khớp thì không gọi BE', (tester) async {
    await pumpPage(tester);

    await fillPasswords(tester, confirm: 'khac-hoan-toan');
    await submit(tester);

    expect(find.text('Vui lòng nhập mã đặt lại mật khẩu'), findsOneWidget);
    expect(find.text('Mật khẩu nhập lại không khớp'), findsOneWidget);
    verifyNever(
      () => repository.resetPassword(
        token: any(named: 'token'),
        newPassword: any(named: 'newPassword'),
      ),
    );
  });

  testWidgets('nút dán lấy token từ bộ nhớ tạm và bỏ khoảng trắng thừa', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return <String, dynamic>{'text': '  pasted-token \n'};
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await pumpPage(tester);

    await tester.tap(find.text('Dán từ bộ nhớ tạm'));
    await tester.pump();

    expect(tester.widget<TextFormField>(field('Mã đặt lại mật khẩu')).controller?.text, 'pasted-token');
  });

  testWidgets('đặt lại thành công thì báo, rồi về màn đăng nhập', (tester) async {
    stubReset().thenAnswer((_) async {});
    await pumpPage(tester, token: 'abc123');

    await fillPasswords(tester);
    await submit(tester);
    await tester.pump();

    verify(() => repository.resetPassword(token: 'abc123', newPassword: 'new-pass-2')).called(1);
    expect(find.text('Đã đặt lại mật khẩu'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.text('Màn đăng nhập'), findsOneWidget);
  });

  testWidgets('đang đăng nhập sẵn thì thiết bị này cũng thoát phiên cũ vì BE đã thu hồi', (tester) async {
    stubReset().thenAnswer((_) async {});
    when(() => repository.logout()).thenAnswer((_) async {});
    authBloc.add(const AuthSignedIn(customerUser));
    await pumpPage(tester, token: 'abc123');

    await fillPasswords(tester);
    await submit(tester);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();

    verify(() => repository.logout()).called(1);
    expect(authBloc.state, const AuthState.unauthenticated());
  });

  testWidgets('chưa đăng nhập thì không gọi đăng xuất', (tester) async {
    stubReset().thenAnswer((_) async {});
    await pumpPage(tester, token: 'abc123');

    await fillPasswords(tester);
    await submit(tester);
    await tester.pump();

    verifyNever(() => repository.logout());
  });

  testWidgets('token sai hoặc hết hạn thì hiện thông báo tiếng Việt và ở lại form', (tester) async {
    stubReset().thenThrow(const ServerFailure('Reset token is invalid or has expired', statusCode: 400));
    await pumpPage(tester, token: 'stale');

    await fillPasswords(tester);
    await submit(tester);
    await tester.pump();

    expect(find.text('Liên kết đặt lại mật khẩu không hợp lệ hoặc đã hết hạn'), findsOneWidget);
    expect(find.text('Đã đặt lại mật khẩu'), findsNothing);
  });

  testWidgets('lỗi validation của BE hiện dưới ô mật khẩu mới', (tester) async {
    stubReset().thenThrow(
      const ServerFailure(
        'Invalid request fields',
        statusCode: 400,
        fieldErrors: {'newPassword': 'newPassword must be 8 to 72 characters'},
      ),
    );
    await pumpPage(tester, token: 'abc123');

    await fillPasswords(tester);
    await submit(tester);
    await tester.pump();

    expect(find.text('newPassword must be 8 to 72 characters'), findsOneWidget);
    expect(find.text('Invalid request fields'), findsNothing);
  });
}
