import 'package:fcourt/features/catalog/domain/entities/court_type_input.dart';
import 'package:fcourt/features/catalog/domain/entities/page_result.dart';
import 'package:fcourt/features/catalog/domain/entities/subscription_plan_input.dart';
import 'package:fcourt/features/catalog/domain/usecases/delete_court_type.dart';
import 'package:fcourt/features/catalog/domain/usecases/delete_subscription_plan.dart';
import 'package:fcourt/features/catalog/domain/usecases/list_court_types.dart';
import 'package:fcourt/features/catalog/domain/usecases/list_subscription_plans.dart';
import 'package:fcourt/features/catalog/domain/usecases/save_court_type.dart';
import 'package:fcourt/features/catalog/domain/usecases/save_subscription_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  late MockCatalogRepository repository;

  setUp(() => repository = MockCatalogRepository());

  group('PageResult', () {
    test('hasMore khi còn trang phía sau (trang bắt đầu từ 0)', () {
      expect(pageOf([badminton], page: 0, totalPages: 2).hasMore, isTrue);
      expect(pageOf([badminton], page: 1, totalPages: 2).hasMore, isFalse);
      expect(pageOf(<int>[], totalPages: 0).hasMore, isFalse);
    });
  });

  group('loại sân', () {
    test('ListCourtTypes hỏi đúng trang với kích thước trang cố định', () async {
      when(() => repository.courtTypes(page: 2, size: ListCourtTypes.pageSize))
          .thenAnswer((_) async => pageOf([badminton], page: 2, totalPages: 3));

      final page = await ListCourtTypes(repository)(2);

      expect(page.items, [badminton]);
      expect(page.page, 2);
    });

    test('SaveCourtType không có id thì tạo mới', () async {
      const input = CourtTypeInput(name: 'Cầu lông');
      when(() => repository.saveCourtType(input)).thenAnswer((_) async => badminton);

      final saved = await SaveCourtType(repository)(input);

      expect(saved, badminton);
      verify(() => repository.saveCourtType(input)).called(1);
    });

    test('SaveCourtType có id thì cập nhật loại sân đó', () async {
      const input = CourtTypeInput(name: 'Cầu lông', active: false);
      when(() => repository.saveCourtType(input, id: 1)).thenAnswer((_) async => badminton);

      await SaveCourtType(repository)(input, id: 1);

      verify(() => repository.saveCourtType(input, id: 1)).called(1);
    });

    test('DeleteCourtType xóa theo id', () async {
      when(() => repository.deleteCourtType(1)).thenAnswer((_) async {});

      await DeleteCourtType(repository)(1);

      verify(() => repository.deleteCourtType(1)).called(1);
    });
  });

  group('gói dịch vụ', () {
    test('ListSubscriptionPlans hỏi đúng trang với kích thước trang cố định', () async {
      when(() => repository.plans(page: 0, size: ListSubscriptionPlans.pageSize))
          .thenAnswer((_) async => pageOf([basicPlan]));

      final page = await ListSubscriptionPlans(repository)(0);

      expect(page.items, [basicPlan]);
    });

    test('SaveSubscriptionPlan không có id thì tạo mới, có id thì cập nhật', () async {
      const input = SubscriptionPlanInput(name: 'Cơ bản', maxBranches: 1, maxCourts: 5);
      when(() => repository.savePlan(input)).thenAnswer((_) async => basicPlan);
      when(() => repository.savePlan(input, id: 1)).thenAnswer((_) async => basicPlan);

      await SaveSubscriptionPlan(repository)(input);
      await SaveSubscriptionPlan(repository)(input, id: 1);

      verify(() => repository.savePlan(input)).called(1);
      verify(() => repository.savePlan(input, id: 1)).called(1);
    });

    test('DeleteSubscriptionPlan xóa theo id', () async {
      when(() => repository.deletePlan(2)).thenAnswer((_) async {});

      await DeleteSubscriptionPlan(repository)(2);

      verify(() => repository.deletePlan(2)).called(1);
    });
  });

  test('PageResult hỗ trợ so sánh theo giá trị', () {
    expect(
      const PageResult<int>(items: [1], page: 0, totalPages: 1, totalElements: 1),
      const PageResult<int>(items: [1], page: 0, totalPages: 1, totalElements: 1),
    );
  });
}
