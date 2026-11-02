import 'dart:async';

import 'package:fcourt/app/auth_redirect.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/auth/domain/usecases/request_password_reset.dart';
import 'package:fcourt/features/auth/presentation/bloc/forgot_password_bloc.dart';
import 'package:fcourt/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => BlocProvider(
            create: (_) => ForgotPasswordBloc(RequestPasswordReset(repository)),
            child: const ForgotPasswordPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.resetPassword,
          builder: (context, state) => Scaffold(appBar: AppBar(), body: const Text('Màn đặt lại mật khẩu')),
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

  Future<void> submit(WidgetTester tester, {String email = 'customer@demo.com'}) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.tap(find.widgetWithText(FilledButton, 'Gửi link đặt lại'));
    await tester.pump();
  }

  testWidgets('để trống hoặc sai định dạng thì báo lỗi và không gọi BE', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Gửi link đặt lại'));
    await tester.pump();
    expect(find.text('Vui lòng nhập email'), findsOneWidget);

    await submit(tester, email: 'not-an-email');
    expect(find.text('Email không hợp lệ'), findsOneWidget);
    verifyNever(() => repository.requestPasswordReset(any()));
  });

  testWidgets('gửi thành công thì báo "nếu email đã đăng ký" chứ không khẳng định email tồn tại', (tester) async {
    when(() => repository.requestPasswordReset('customer@demo.com')).thenAnswer((_) async {});
    await pumpPage(tester);

    await submit(tester);
    await tester.pump();

    expect(find.textContaining('Nếu customer@demo.com đã đăng ký'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Gửi link đặt lại'), findsNothing);
  });

  testWidgets('sau khi gửi có thể sang màn nhập mã hoặc về đăng nhập', (tester) async {
    when(() => repository.requestPasswordReset(any())).thenAnswer((_) async {});
    await pumpPage(tester);
    await submit(tester);
    await tester.pump();

    await tester.tap(find.text('Nhập mã đặt lại mật khẩu'));
    await tester.pumpAndSettle();
    expect(find.text('Màn đặt lại mật khẩu'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Về màn hình đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Màn đăng nhập'), findsOneWidget);
  });

  testWidgets('mất mạng thì hiện thông báo và vẫn ở form để thử lại', (tester) async {
    when(() => repository.requestPasswordReset(any())).thenThrow(const NetworkFailure());
    await pumpPage(tester);

    await submit(tester);
    await tester.pump();

    expect(find.text('Không kết nối được máy chủ'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Gửi link đặt lại'), findsOneWidget);
  });

  testWidgets('đang gửi thì nút bị khóa và hiện vòng chờ', (tester) async {
    final completer = Completer<void>();
    when(() => repository.requestPasswordReset(any())).thenAnswer((_) => completer.future);
    await pumpPage(tester);

    await submit(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    completer.complete();
    await tester.pump();
  });
}
