import 'package:fcourt/app/auth_redirect.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/auth/domain/entities/upload_document.dart';
import 'package:fcourt/features/auth/domain/usecases/register_court_owner.dart';
import 'package:fcourt/features/auth/domain/usecases/register_customer.dart';
import 'package:fcourt/features/auth/presentation/bloc/register_bloc.dart';
import 'package:fcourt/features/auth/presentation/pages/register_owner_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  const licence = UploadDocument(name: 'licence.pdf', path: '/tmp/licence.pdf');
  const citizenId = UploadDocument(name: 'id.png', path: '/tmp/id.png');
  const front = UploadDocument(name: 'front.jpg', path: '/tmp/front.jpg');

  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  Future<void> pumpPage(WidgetTester tester, FakeDocumentPicker picker) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => BlocProvider(
            create: (_) => RegisterBloc(
              RegisterCustomer(repository),
              RegisterCourtOwner(repository),
            ),
            child: RegisterOwnerPage(picker: picker),
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

  Future<void> fillForm(WidgetTester tester) async {
    await tester.enterText(field('Họ và tên chủ sân'), 'Chu San');
    await tester.enterText(field('Email'), 'owner@demo.com');
    await tester.enterText(field('Số điện thoại'), '0909000003');
    await tester.enterText(field('Mật khẩu'), 'S3cret-pass');
    await tester.enterText(field('Nhập lại mật khẩu'), 'S3cret-pass');
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Gửi hồ sơ đăng ký'));
    await tester.pump();
  }

  Future<void> pickLegal(WidgetTester tester) async {
    await tester.tap(find.textContaining('Chọn giấy tờ'));
    await tester.pump();
  }

  When<Future<void>> stubRegister() => when(
        () => repository.registerCourtOwner(
          fullName: any(named: 'fullName'),
          email: any(named: 'email'),
          phone: any(named: 'phone'),
          password: any(named: 'password'),
          legalDocuments: any(named: 'legalDocuments'),
          courtImages: any(named: 'courtImages'),
        ),
      );

  testWidgets('thiếu giấy tờ pháp lý thì báo lỗi dù các ô khác hợp lệ', (tester) async {
    await pumpPage(tester, FakeDocumentPicker([]));

    await fillForm(tester);
    await submit(tester);

    expect(find.text('Vui lòng chọn ít nhất 1 giấy tờ pháp lý'), findsOneWidget);
    verifyNever(
      () => repository.registerCourtOwner(
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        phone: any(named: 'phone'),
        password: any(named: 'password'),
        legalDocuments: any(named: 'legalDocuments'),
        courtImages: any(named: 'courtImages'),
      ),
    );
  });

  testWidgets('chọn tệp thì hiện trong danh sách; giấy tờ nhận PDF, ảnh sân thì không', (tester) async {
    final picker = FakeDocumentPicker([
      [licence, citizenId],
      [front],
    ]);
    await pumpPage(tester, picker);

    await pickLegal(tester);
    await tester.tap(find.textContaining('Chọn ảnh sân'));
    await tester.pump();

    expect(find.text('licence.pdf'), findsOneWidget);
    expect(find.text('id.png'), findsOneWidget);
    expect(find.text('front.jpg'), findsOneWidget);
    expect(find.text('Chọn giấy tờ (2/5)'), findsOneWidget);
    expect(picker.allowPdfCalls, [true, false]);
  });

  testWidgets('bỏ tệp đã chọn và không thêm trùng một tệp hai lần', (tester) async {
    final picker = FakeDocumentPicker([
      [licence],
      [licence, citizenId],
    ]);
    await pumpPage(tester, picker);

    await pickLegal(tester);
    await pickLegal(tester);
    expect(find.text('licence.pdf'), findsOneWidget);
    expect(find.text('id.png'), findsOneWidget);

    await tester.tap(find.byTooltip('Bỏ tệp licence.pdf'));
    await tester.pump();

    expect(find.text('licence.pdf'), findsNothing);
    expect(find.text('id.png'), findsOneWidget);
  });

  testWidgets('chỉ nhận tối đa 5 giấy tờ pháp lý', (tester) async {
    final many = [
      for (var i = 0; i < 7; i++) UploadDocument(name: 'doc$i.pdf', path: '/tmp/doc$i.pdf'),
    ];
    await pumpPage(tester, FakeDocumentPicker([many]));

    await pickLegal(tester);

    expect(find.text('Chọn giấy tờ (5/5)'), findsOneWidget);
    expect(find.text('doc4.pdf'), findsOneWidget);
    expect(find.text('doc5.pdf'), findsNothing);
  });

  testWidgets('gửi hồ sơ kèm đúng tệp rồi hiện thông báo chờ duyệt và về đăng nhập', (tester) async {
    stubRegister().thenAnswer((_) async {});
    final picker = FakeDocumentPicker([
      [licence],
      [front],
    ]);
    await pumpPage(tester, picker);

    await fillForm(tester);
    await pickLegal(tester);
    await tester.tap(find.textContaining('Chọn ảnh sân'));
    await tester.pump();
    await submit(tester);
    await tester.pump();

    verify(
      () => repository.registerCourtOwner(
        fullName: 'Chu San',
        email: 'owner@demo.com',
        phone: '0909000003',
        password: 'S3cret-pass',
        legalDocuments: [licence],
        courtImages: [front],
      ),
    ).called(1);
    expect(find.text('Đã gửi hồ sơ'), findsOneWidget);

    await tester.tap(find.text('Về màn hình đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.text('Màn đăng nhập'), findsOneWidget);
  });

  testWidgets('kho tài liệu của BE lỗi thì hiện thông báo tiếng Việt và giữ nguyên tệp đã chọn', (tester) async {
    stubRegister().thenThrow(const ServerFailure('Document storage is unavailable', statusCode: 503));
    await pumpPage(tester, FakeDocumentPicker([[licence]]));

    await fillForm(tester);
    await pickLegal(tester);
    await submit(tester);
    await tester.pump();

    expect(find.text('Hệ thống lưu tài liệu đang bận, vui lòng thử lại sau'), findsOneWidget);
    expect(find.text('licence.pdf'), findsOneWidget);
    expect(find.text('Đã gửi hồ sơ'), findsNothing);
  });

  testWidgets('lỗi của BE về giấy tờ hiện ngay dưới danh sách giấy tờ', (tester) async {
    stubRegister().thenThrow(
      const ServerFailure(
        'Invalid request fields',
        statusCode: 400,
        fieldErrors: {'legalDocuments': 'legalDocuments is required'},
      ),
    );
    await pumpPage(tester, FakeDocumentPicker([[licence]]));

    await fillForm(tester);
    await pickLegal(tester);
    await submit(tester);
    await tester.pump();

    expect(find.text('Vui lòng chọn ít nhất 1 giấy tờ pháp lý'), findsOneWidget);
  });
}
