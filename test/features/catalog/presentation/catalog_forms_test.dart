import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/catalog/domain/entities/court_type_input.dart';
import 'package:fcourt/features/catalog/domain/entities/subscription_plan_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../catalog_harness.dart';
import '../helpers.dart';

void main() {
  late MockCatalogRepository repository;

  setUpAll(() {
    registerFallbackValue(const CourtTypeInput(name: 'fallback'));
    registerFallbackValue(
      const SubscriptionPlanInput(name: 'fallback', maxBranches: 1, maxCourts: 1),
    );
  });

  setUp(() {
    repository = MockCatalogRepository();
    stubLists(repository);
  });

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await settle(tester);
  }

  group('loại sân', () {
    Future<void> openCreateForm(WidgetTester tester) async {
      await pumpCatalog(tester, repository);
      await tester.tap(find.text('Thêm loại sân'));
      await tester.pumpAndSettle();
    }

    testWidgets('thêm mới: để trống tên thì báo lỗi và không gọi BE', (tester) async {
      await openCreateForm(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Thêm loại sân'));
      await tester.pump();

      expect(find.text('Vui lòng nhập tên loại sân'), findsOneWidget);
      verifyNever(() => repository.saveCourtType(any(), id: any(named: 'id')));
    });

    testWidgets('thêm mới: tên quá 100 ký tự thì báo lỗi ngay', (tester) async {
      await openCreateForm(tester);

      await tester.enterText(field('Tên loại sân'), 'a' * 101);
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm loại sân'));
      await tester.pump();

      expect(find.text('tên loại sân tối đa 100 ký tự'), findsOneWidget);
    });

    testWidgets('thêm mới thành công: gửi đúng dữ liệu, đóng form, tải lại danh sách và báo đã thêm', (tester) async {
      when(() => repository.saveCourtType(any())).thenAnswer((_) async => badminton);
      await openCreateForm(tester);

      await tester.enterText(field('Tên loại sân'), '  Tennis  ');
      await tester.enterText(field('Tên tiếng Anh (không bắt buộc)'), 'Tennis');
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm loại sân'));
      await settle(tester);

      verify(
        () => repository.saveCourtType(
          const CourtTypeInput(name: 'Tennis', nameEn: 'Tennis'),
        ),
      ).called(1);
      expect(find.text('Thêm loại sân'), findsOneWidget); // chỉ còn nút nổi của danh sách
      expect(find.text('Đã thêm loại sân'), findsOneWidget);
      verify(() => repository.courtTypes(page: 0, size: 20)).called(2);
    });

    testWidgets('sửa: form điền sẵn dữ liệu cũ và gửi kèm id', (tester) async {
      when(() => repository.saveCourtType(any(), id: any(named: 'id')))
          .thenAnswer((_) async => badminton);
      await pumpCatalog(tester, repository);

      await tester.tap(find.text('Cầu lông'));
      await tester.pumpAndSettle();

      expect(find.text('Sửa loại sân'), findsOneWidget);
      expect(tester.widget<TextFormField>(field('Tên loại sân')).controller?.text, 'Cầu lông');
      expect(
        tester.widget<TextFormField>(field('Tên tiếng Anh (không bắt buộc)')).controller?.text,
        'Badminton',
      );

      await tester.enterText(field('Tên loại sân'), 'Cầu lông 2');
      await tester.tap(find.widgetWithText(SwitchListTile, 'Đang hoạt động'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu thay đổi'));
      await settle(tester);

      verify(
        () => repository.saveCourtType(
          const CourtTypeInput(
            name: 'Cầu lông 2',
            nameEn: 'Badminton',
            description: 'Sân cầu lông trong nhà',
            color: '#0B7A4B',
            active: false,
          ),
          id: 1,
        ),
      ).called(1);
      expect(find.text('Đã lưu loại sân'), findsOneWidget);
    });

    testWidgets('tên trùng: hiện thông báo tiếng Việt và form vẫn mở để sửa', (tester) async {
      when(() => repository.saveCourtType(any())).thenThrow(
        const ServerFailure('Court type name already exists', statusCode: 409),
      );
      await openCreateForm(tester);

      await tester.enterText(field('Tên loại sân'), 'Cầu lông');
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm loại sân'));
      await settle(tester);

      expect(find.text('Tên loại sân đã tồn tại'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Thêm loại sân'), findsOneWidget);
    });

    testWidgets('lỗi validation của BE hiện ngay dưới ô tương ứng', (tester) async {
      when(() => repository.saveCourtType(any())).thenThrow(
        const ServerFailure(
          'Invalid request fields',
          statusCode: 400,
          fieldErrors: {'color': 'color must be at most 20 characters'},
        ),
      );
      await openCreateForm(tester);

      await tester.enterText(field('Tên loại sân'), 'Tennis');
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm loại sân'));
      await settle(tester);

      expect(find.text('color must be at most 20 characters'), findsOneWidget);
      expect(find.text('Dữ liệu chưa hợp lệ, vui lòng kiểm tra lại các ô bên dưới'), findsNothing);
    });
  });

  group('gói dịch vụ', () {
    Future<void> openCreateForm(WidgetTester tester) async {
      await pumpCatalog(tester, repository);
      await tapAndSettle(tester, find.text('Gói dịch vụ'));
      await tester.tap(find.text('Thêm gói'));
      await tester.pumpAndSettle();
    }

    Future<void> fillRequired(WidgetTester tester) async {
      await tester.enterText(field('Tên gói'), 'Gói thử');
      await tester.enterText(field('Số chi nhánh tối đa'), '2');
      await tester.enterText(field('Số sân tối đa'), '10');
    }

    testWidgets('thêm mới: thiếu tên và giới hạn thì báo lỗi từng ô', (tester) async {
      await openCreateForm(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Thêm gói dịch vụ'));
      await tester.pump();

      expect(find.text('Vui lòng nhập tên gói'), findsOneWidget);
      expect(find.text('Vui lòng nhập Số chi nhánh'), findsOneWidget);
      expect(find.text('Vui lòng nhập Số sân'), findsOneWidget);
      verifyNever(() => repository.savePlan(any(), id: any(named: 'id')));
    });

    testWidgets('giới hạn phải từ 1 trở lên', (tester) async {
      await openCreateForm(tester);

      await tester.enterText(field('Tên gói'), 'Gói thử');
      await tester.enterText(field('Số chi nhánh tối đa'), '0');
      await tester.enterText(field('Số sân tối đa'), '0');
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm gói dịch vụ'));
      await tester.pump();

      expect(find.text('Số chi nhánh phải từ 1 trở lên'), findsOneWidget);
      expect(find.text('Số sân phải từ 1 trở lên'), findsOneWidget);
    });

    testWidgets('quá 30 tính năng thì báo lỗi ngay', (tester) async {
      await openCreateForm(tester);

      await fillRequired(tester);
      await tester.enterText(
        field('Tính năng (không bắt buộc)'),
        List.generate(31, (i) => 'Tính năng $i').join('\n'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm gói dịch vụ'));
      await tester.pump();

      expect(find.text('Tối đa 30 tính năng'), findsOneWidget);
    });

    testWidgets('giá để trống thì gửi null (không bán), tính năng bỏ dòng trống và trùng', (tester) async {
      when(() => repository.savePlan(any())).thenAnswer((_) async => basicPlan);
      await openCreateForm(tester);

      await fillRequired(tester);
      await tester.enterText(field('Tính năng (không bắt buộc)'), 'A\n\n B \nA');
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm gói dịch vụ'));
      await settle(tester);

      verify(
        () => repository.savePlan(
          const SubscriptionPlanInput(
            name: 'Gói thử',
            maxBranches: 2,
            maxCourts: 10,
            features: ['A', 'B'],
          ),
        ),
      ).called(1);
      expect(find.text('Đã thêm gói dịch vụ'), findsOneWidget);
      verify(() => repository.plans(page: 0, size: 20)).called(2);
    });

    testWidgets('nhập giá theo tháng và năm, đánh dấu phổ biến', (tester) async {
      when(() => repository.savePlan(any())).thenAnswer((_) async => basicPlan);
      await openCreateForm(tester);

      await fillRequired(tester);
      await tester.enterText(field('Giá theo tháng (VND)'), '199000');
      await tester.enterText(field('Giá theo năm (VND)'), '1990000');
      await tester.tap(find.widgetWithText(SwitchListTile, 'Gói phổ biến'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm gói dịch vụ'));
      await settle(tester);

      verify(
        () => repository.savePlan(
          const SubscriptionPlanInput(
            name: 'Gói thử',
            maxBranches: 2,
            maxCourts: 10,
            monthlyPrice: 199000,
            yearlyPrice: 1990000,
            popular: true,
          ),
        ),
      ).called(1);
    });

    testWidgets('ô giá chỉ nhận chữ số', (tester) async {
      await openCreateForm(tester);

      await tester.enterText(field('Giá theo tháng (VND)'), '1a9-9,0.0');

      expect(tester.widget<TextFormField>(field('Giá theo tháng (VND)')).controller?.text, '19900');
    });

    testWidgets('sửa: điền sẵn giá, tính năng, trạng thái và gửi kèm id', (tester) async {
      when(() => repository.savePlan(any(), id: any(named: 'id')))
          .thenAnswer((_) async => basicPlan);
      await pumpCatalog(tester, repository);
      await tapAndSettle(tester, find.text('Gói dịch vụ'));

      await tester.tap(find.text('Cơ bản'));
      await tester.pumpAndSettle();

      expect(find.text('Sửa gói dịch vụ'), findsOneWidget);
      expect(tester.widget<TextFormField>(field('Giá theo tháng (VND)')).controller?.text, '199000');
      expect(
        tester.widget<TextFormField>(field('Tính năng (không bắt buộc)')).controller?.text,
        'Quản lý đặt sân\nBáo cáo doanh thu',
      );

      await tester.enterText(field('Giá theo năm (VND)'), '');
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu thay đổi'));
      await settle(tester);

      verify(
        () => repository.savePlan(
          const SubscriptionPlanInput(
            name: 'Cơ bản',
            tagline: 'Cho chủ sân nhỏ',
            monthlyPrice: 199000,
            maxBranches: 1,
            maxCourts: 5,
            features: ['Quản lý đặt sân', 'Báo cáo doanh thu'],
          ),
          id: 1,
        ),
      ).called(1);
      expect(find.text('Đã lưu gói dịch vụ'), findsOneWidget);
    });

    testWidgets('tên gói trùng thì hiện thông báo tiếng Việt và giữ form', (tester) async {
      when(() => repository.savePlan(any())).thenThrow(
        const ServerFailure('Subscription plan name already exists', statusCode: 409),
      );
      await openCreateForm(tester);

      await fillRequired(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm gói dịch vụ'));
      await settle(tester);

      expect(find.text('Tên gói dịch vụ đã tồn tại'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Thêm gói dịch vụ'), findsOneWidget);
    });

    testWidgets('lỗi validation của BE hiện dưới đúng ô giá', (tester) async {
      when(() => repository.savePlan(any())).thenThrow(
        const ServerFailure(
          'Invalid request fields',
          statusCode: 400,
          fieldErrors: {'monthlyPrice': 'monthlyPrice must not be negative'},
        ),
      );
      await openCreateForm(tester);

      await fillRequired(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Thêm gói dịch vụ'));
      await settle(tester);

      expect(find.text('monthlyPrice must not be negative'), findsOneWidget);
    });
  });
}
