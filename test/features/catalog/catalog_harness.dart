import 'package:fcourt/features/catalog/domain/entities/court_type.dart';
import 'package:fcourt/features/catalog/domain/entities/subscription_plan.dart';
import 'package:fcourt/features/catalog/domain/usecases/delete_court_type.dart';
import 'package:fcourt/features/catalog/domain/usecases/delete_subscription_plan.dart';
import 'package:fcourt/features/catalog/domain/usecases/list_court_types.dart';
import 'package:fcourt/features/catalog/domain/usecases/list_subscription_plans.dart';
import 'package:fcourt/features/catalog/domain/usecases/save_court_type.dart';
import 'package:fcourt/features/catalog/domain/usecases/save_subscription_plan.dart';
import 'package:fcourt/features/catalog/presentation/bloc/catalog_list_bloc.dart';
import 'package:fcourt/features/catalog/presentation/pages/catalog_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers.dart';

/// Dựng `CatalogPage` (chưa chờ tải xong) với hai list bloc thật, nối y như router, trên một [repository] giả.
Future<void> pumpCatalogWithoutSettling(
  WidgetTester tester,
  MockCatalogRepository repository,
) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => CatalogListBloc<CourtType>(
              load: ListCourtTypes(repository).call,
              delete: DeleteCourtType(repository).call,
              idOf: (courtType) => courtType.id,
              deletedMessage: 'Đã xóa loại sân',
            )..add(const CatalogRefreshed()),
          ),
          BlocProvider(
            create: (_) => CatalogListBloc<SubscriptionPlan>(
              load: ListSubscriptionPlans(repository).call,
              delete: DeleteSubscriptionPlan(repository).call,
              idOf: (plan) => plan.id,
              deletedMessage: 'Đã xóa gói dịch vụ',
            )..add(const CatalogRefreshed()),
          ),
        ],
        child: CatalogPage(
          saveCourtType: SaveCourtType(repository),
          saveSubscriptionPlan: SaveSubscriptionPlan(repository),
        ),
      ),
    ),
  );
}

/// Như [pumpCatalogWithoutSettling] rồi chờ dữ liệu tải xong.
Future<void> pumpCatalog(WidgetTester tester, MockCatalogRepository repository) async {
  await pumpCatalogWithoutSettling(tester, repository);
  await settle(tester);
}

/// Bloc xử lý sự kiện qua stream nên cần một nhịp event loop thật; pump giả của test không đủ.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pumpAndSettle();
}

/// Stub hai danh sách mặc định: 2 loại sân và 2 gói, một trang.
void stubLists(MockCatalogRepository repository) {
  when(() => repository.courtTypes(page: 0, size: 20))
      .thenAnswer((_) async => pageOf([badminton, football]));
  when(() => repository.plans(page: 0, size: 20))
      .thenAnswer((_) async => pageOf([basicPlan, proPlan]));
}
