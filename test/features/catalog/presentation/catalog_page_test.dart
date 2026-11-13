import 'dart:async';

import 'package:fcourt/core/error/failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../catalog_harness.dart';
import '../helpers.dart';

void main() {
  late MockCatalogRepository repository;

  setUp(() => repository = MockCatalogRepository());

  Future<void> openPlansTab(WidgetTester tester) async {
    await tester.tap(find.text('Gói dịch vụ'));
    await tester.pumpAndSettle();
  }

  group('hiển thị danh sách', () {
    testWidgets('tab loại sân liệt kê tên, mô tả và trạng thái', (tester) async {
      stubLists(repository);

      await pumpCatalog(tester, repository);

      expect(find.text('Danh mục hệ thống'), findsOneWidget);
      expect(find.text('Cầu lông'), findsOneWidget);
      expect(find.textContaining('Badminton'), findsOneWidget);
      expect(find.text('Bóng đá mini'), findsOneWidget);
      expect(find.text('Hoạt động'), findsOneWidget);
      expect(find.text('Tạm ngưng'), findsOneWidget);
    });

    testWidgets('tab gói dịch vụ hiện giá VND, giới hạn và nhãn phổ biến', (tester) async {
      stubLists(repository);
      await pumpCatalog(tester, repository);

      await openPlansTab(tester);

      expect(find.text('Cơ bản'), findsOneWidget);
      expect(find.text('199.000 ₫ / tháng'), findsOneWidget);
      expect(find.text('1.990.000 ₫ / năm'), findsOneWidget);
      expect(find.text('Tối đa 1 chi nhánh · 5 sân'), findsOneWidget);
      expect(find.text('2 tính năng'), findsOneWidget);
      expect(find.text('Chuyên nghiệp'), findsOneWidget);
      expect(find.text('Không bán / năm'), findsOneWidget);
      expect(find.text('Phổ biến'), findsOneWidget);
      expect(find.text('Đang bán'), findsOneWidget);
    });

    testWidgets('đang tải thì hiện vòng chờ', (tester) async {
      final completer = Completer<Never>();
      when(() => repository.courtTypes(page: 0, size: 20)).thenAnswer((_) => completer.future);
      when(() => repository.plans(page: 0, size: 20)).thenAnswer((_) => completer.future);

      await pumpCatalogWithoutSettling(tester, repository);

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('danh sách rỗng thì báo chưa có mục nào', (tester) async {
      when(() => repository.courtTypes(page: 0, size: 20)).thenAnswer((_) async => pageOf([]));
      when(() => repository.plans(page: 0, size: 20)).thenAnswer((_) async => pageOf([]));

      await pumpCatalog(tester, repository);
      expect(find.text('Chưa có loại sân nào'), findsOneWidget);

      await openPlansTab(tester);
      expect(find.text('Chưa có gói dịch vụ nào'), findsOneWidget);
    });

    testWidgets('lỗi tải thì có nút thử lại và tải được sau khi thử lại', (tester) async {
      var attempts = 0;
      when(() => repository.courtTypes(page: 0, size: 20)).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) throw const NetworkFailure();
        return pageOf([badminton]);
      });
      when(() => repository.plans(page: 0, size: 20)).thenAnswer((_) async => pageOf([basicPlan]));

      await pumpCatalog(tester, repository);
      expect(find.text('Không kết nối được máy chủ'), findsOneWidget);

      await tester.tap(find.text('Thử lại'));
      await settle(tester);

      expect(find.text('Cầu lông'), findsOneWidget);
      expect(find.text('Không kết nối được máy chủ'), findsNothing);
    });

    testWidgets('còn trang sau thì có nút tải thêm và nối kết quả vào danh sách', (tester) async {
      when(() => repository.courtTypes(page: 0, size: 20))
          .thenAnswer((_) async => pageOf([badminton], totalPages: 2));
      when(() => repository.courtTypes(page: 1, size: 20))
          .thenAnswer((_) async => pageOf([football], page: 1, totalPages: 2));
      when(() => repository.plans(page: 0, size: 20)).thenAnswer((_) async => pageOf([]));

      await pumpCatalog(tester, repository);
      expect(find.text('Bóng đá mini'), findsNothing);

      await tester.tap(find.text('Tải thêm'));
      await settle(tester);

      expect(find.text('Cầu lông'), findsOneWidget);
      expect(find.text('Bóng đá mini'), findsOneWidget);
      expect(find.text('Tải thêm'), findsNothing);
    });

    testWidgets('kéo xuống để làm mới thì tải lại từ trang đầu', (tester) async {
      stubLists(repository);
      await pumpCatalog(tester, repository);

      // Kéo từng bước như ngón tay thật. Ngưỡng của RefreshIndicator tính theo chiều cao màn hình
      // (2400 px trong test) nên phải kéo đủ xa.
      final gesture = await tester.startGesture(tester.getCenter(find.text('Cầu lông')));
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(0, 150));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
      await settle(tester);

      verify(() => repository.courtTypes(page: 0, size: 20)).called(2);
    });
  });

  group('xóa', () {
    testWidgets('xóa loại sân sau khi xác nhận: gọi BE, bỏ khỏi danh sách và báo đã xóa', (tester) async {
      stubLists(repository);
      when(() => repository.deleteCourtType(1)).thenAnswer((_) async {});
      await pumpCatalog(tester, repository);

      await tester.tap(find.byTooltip('Xóa Cầu lông'));
      await tester.pumpAndSettle();
      expect(find.text('Xóa loại sân?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await settle(tester);

      verify(() => repository.deleteCourtType(1)).called(1);
      expect(find.text('Cầu lông'), findsNothing);
      expect(find.text('Bóng đá mini'), findsOneWidget);
      expect(find.text('Đã xóa loại sân'), findsOneWidget);
    });

    testWidgets('hủy hộp thoại xác nhận thì không xóa', (tester) async {
      stubLists(repository);
      await pumpCatalog(tester, repository);

      await tester.tap(find.byTooltip('Xóa Cầu lông'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await settle(tester);

      verifyNever(() => repository.deleteCourtType(any()));
      expect(find.text('Cầu lông'), findsOneWidget);
    });

    testWidgets('xóa lỗi thì giữ mục và báo lỗi bằng tiếng Việt', (tester) async {
      stubLists(repository);
      when(() => repository.deleteCourtType(1)).thenThrow(
        const ServerFailure('Court type not found', statusCode: 404),
      );
      await pumpCatalog(tester, repository);

      await tester.tap(find.byTooltip('Xóa Cầu lông'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await settle(tester);

      expect(find.text('Cầu lông'), findsOneWidget);
      expect(find.text('Loại sân không còn tồn tại, hãy tải lại danh sách'), findsOneWidget);
    });

    testWidgets('không phải super admin: 403 được báo bằng tiếng Việt', (tester) async {
      stubLists(repository);
      when(() => repository.deleteCourtType(1)).thenThrow(
        const ServerFailure('You are not allowed to perform this action', statusCode: 403),
      );
      await pumpCatalog(tester, repository);

      await tester.tap(find.byTooltip('Xóa Cầu lông'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await settle(tester);

      expect(find.text('Bạn không có quyền thực hiện thao tác này'), findsOneWidget);
    });

    testWidgets('xóa gói dịch vụ: nói rõ chủ sân đã mua vẫn dùng bình thường', (tester) async {
      stubLists(repository);
      when(() => repository.deletePlan(1)).thenAnswer((_) async {});
      await pumpCatalog(tester, repository);
      await openPlansTab(tester);

      await tester.tap(find.byTooltip('Xóa Cơ bản'));
      await tester.pumpAndSettle();
      expect(find.textContaining('vẫn tiếp tục dùng bình thường'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await settle(tester);

      verify(() => repository.deletePlan(1)).called(1);
      expect(find.text('Cơ bản'), findsNothing);
      expect(find.text('Đã xóa gói dịch vụ'), findsOneWidget);
    });
  });
}
