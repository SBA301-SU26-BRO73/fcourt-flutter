import 'dart:async';

import 'package:fcourt/app/app.dart';
import 'package:fcourt/app/app_dependencies.dart';
import 'package:fcourt/core/config/app_config.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/health/domain/entities/health_status.dart';
import 'package:fcourt/features/health/domain/repositories/health_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../features/auth/helpers.dart';
import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';

class _FakeHealthRepository implements HealthRepository {
  @override
  Future<HealthStatus> check() async => const HealthStatus('ok');
}

class _FakeDiscoveryRepository implements DiscoveryRepository {
  @override
  Future<BranchPage> search({
    String query = '',
    DiscoverySport? sport,
    int page = 0,
  }) async =>
      const BranchPage(branches: [], page: 0, totalPages: 0, totalElements: 0);
}

void main() {
  late MockAuthRepository repository;
  late StreamController<void> sessionExpired;

  setUp(() {
    repository = MockAuthRepository();
    sessionExpired = StreamController<void>.broadcast();
  });

  tearDown(() => sessionExpired.close());

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      FcourtApp(
        dependencies: AppDependencies(
          config: const AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://test'),
          healthRepository: _FakeHealthRepository(),
          authRepository: repository,
          discoveryRepository: _FakeDiscoveryRepository(),
          sessionExpired: sessionExpired.stream,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('chưa có phiên thì vào màn đăng nhập', (tester) async {
    when(() => repository.restoreSession()).thenAnswer((_) async => null);

    await pumpApp(tester);

    expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
    expect(find.text('Xin chào, An Nguyen'), findsNothing);
  });

  testWidgets('đang khôi phục phiên thì hiện màn chờ, không nháy màn đăng nhập', (tester) async {
    final completer = Completer<Never>();
    when(() => repository.restoreSession()).thenAnswer((_) => completer.future);
    await tester.pumpWidget(
      FcourtApp(
        dependencies: AppDependencies(
          config: const AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://test'),
          healthRepository: _FakeHealthRepository(),
          authRepository: repository,
          discoveryRepository: _FakeDiscoveryRepository(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsNothing);
  });

  testWidgets('có phiên cũ thì vào thẳng trang chủ theo vai trò', (tester) async {
    when(() => repository.restoreSession()).thenAnswer((_) async => adminUser);

    await pumpApp(tester);

    expect(find.text('Quản lý cụm sân'), findsOneWidget);
    expect(find.text('Xin chào, Chu San'), findsOneWidget);
  });

  testWidgets('không hỏi được máy chủ khi khởi động thì về màn đăng nhập', (tester) async {
    when(() => repository.restoreSession()).thenThrow(const NetworkFailure());

    await pumpApp(tester);

    expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
  });

  testWidgets('đăng nhập xong thì sang trang chủ và không quay lại được màn đăng nhập', (tester) async {
    when(() => repository.restoreSession()).thenAnswer((_) async => null);
    when(() => repository.login(email: 'customer@demo.com', password: 'S3cret-pass'))
        .thenAnswer((_) async => customerUser);
    await pumpApp(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'customer@demo.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mật khẩu'), 'S3cret-pass');
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.text('Đặt sân'), findsOneWidget);
    expect(find.text('Xin chào, An Nguyen'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsNothing);
  });

  testWidgets('refresh token hết hạn thì đưa người dùng về màn đăng nhập', (tester) async {
    when(() => repository.restoreSession()).thenAnswer((_) async => customerUser);
    await pumpApp(tester);
    expect(find.text('Xin chào, An Nguyen'), findsOneWidget);

    sessionExpired.add(null);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
    expect(find.text('Xin chào, An Nguyen'), findsNothing);
  });

  testWidgets('đăng xuất từ trang tài khoản đưa về màn đăng nhập', (tester) async {
    when(() => repository.restoreSession()).thenAnswer((_) async => customerUser);
    when(() => repository.logout()).thenAnswer((_) async {});
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Tài khoản'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Đăng xuất'));
    await tester.pumpAndSettle();

    verify(() => repository.logout()).called(1);
    expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
  });

  testWidgets('từ màn đăng nhập mở được hai màn đăng ký', (tester) async {
    when(() => repository.restoreSession()).thenAnswer((_) async => null);
    await pumpApp(tester);

    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng ký khách hàng'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng ký làm chủ sân'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng ký chủ sân'), findsOneWidget);
  });

  testWidgets('khách hàng mở được màn tìm sân và màn kiểm tra kết nối', (tester) async {
    when(() => repository.restoreSession()).thenAnswer((_) async => customerUser);
    await pumpApp(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Tìm sân'));
    await tester.pumpAndSettle();
    expect(find.text('FCOURT'), findsOneWidget);
    expect(find.text('Ra sân. Hết mình.'), findsOneWidget);

    await tester.tap(find.byTooltip('Kiểm tra kết nối'));
    await tester.pumpAndSettle();
    expect(find.text('Máy chủ: ok'), findsOneWidget);
  });
}
