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

import '../../../helpers/wp3b_shots.dart';
import '../catalog_harness.dart';
import '../helpers.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('catalog matches the WP3b look (${b.name})', (tester) async {
      final repository = MockCatalogRepository();
      stubLists(repository);
      await pumpShot(
        tester,
        b,
        CatalogPage(
          saveCourtType: SaveCourtType(repository),
          saveSubscriptionPlan: SaveSubscriptionPlan(repository),
        ),
        name: 'catalog',
        prepare: settle,
        wrap: (child) => MultiBlocProvider(
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
          child: child,
        ),
      );
      expect(find.text('Danh mục hệ thống'), findsOneWidget);
    });
  }
}
