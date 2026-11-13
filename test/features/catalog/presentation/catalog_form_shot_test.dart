import 'package:fcourt/features/catalog/domain/entities/court_type_input.dart';
import 'package:fcourt/features/catalog/domain/entities/subscription_plan_input.dart';
import 'package:fcourt/features/catalog/presentation/bloc/catalog_form_bloc.dart';
import 'package:fcourt/features/catalog/presentation/pages/court_type_form_page.dart';
import 'package:fcourt/features/catalog/presentation/pages/subscription_plan_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/wp3b_shots.dart';
import '../helpers.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('court type form matches the WP3b look (${b.name})', (
      tester,
    ) async {
      await pumpShot(
        tester,
        b,
        CourtTypeFormPage(editing: badminton),
        name: 'catalog-court-type-form',
        wrap: (child) => BlocProvider(
          create: (_) => CatalogFormBloc<CourtTypeInput>((_) async {}),
          child: child,
        ),
      );
      expect(find.text('Sửa loại sân'), findsOneWidget);
    });
    testWidgets('plan form matches the WP3b look (${b.name})', (tester) async {
      await pumpShot(
        tester,
        b,
        SubscriptionPlanFormPage(editing: basicPlan),
        name: 'catalog-plan-form',
        wrap: (child) => BlocProvider(
          create: (_) => CatalogFormBloc<SubscriptionPlanInput>((_) async {}),
          child: child,
        ),
      );
      expect(find.text('Sửa gói dịch vụ'), findsOneWidget);
    });
  }
}
