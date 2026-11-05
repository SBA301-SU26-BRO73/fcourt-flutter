import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fcourt/features/subscription/presentation/subscription_screen.dart';
import 'package:fcourt/features/subscription/presentation/subscription_cubit.dart';
import 'package:fcourt/features/subscription/presentation/plan_comparison.dart';
import 'package:fcourt/features/subscription/data/subscription_models.dart';

import 'fixtures.dart';

void main() {
  testWidgets(
    'current plan shows backend snapshot limits and inclusive calendar dates',
    (tester) async {
      final cubit = SubscriptionCubit(Billing(), CheckoutLauncher());
      addTearDown(cubit.close);
      await cubit.refresh();
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const SubscriptionScreen(),
          ),
        ),
      );
      expect(find.text('Đang có hiệu lực'), findsOneWidget);
      expect(
        find.text('Hạn mức hiện tại: 1 chi nhánh · 2 sân'),
        findsOneWidget,
      );
      expect(find.text('Hiệu lực: 01/01/2026 – 31/12/2026'), findsOneWidget);
    },
  );
  testWidgets(
    'plan comparison honors null cycles and popular flag without a recommendation',
    (tester) async {
      final plans = [
        SubscriptionModels.plan({...planJson(), 'monthlyPrice': null}),
        SubscriptionModels.plan(planJson(id: 2, popular: true)),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: PlanComparison(plans: plans)),
          ),
        ),
      );
      await tester.tap(find.text('So sánh gói dịch vụ'));
      await tester.pumpAndSettle();
      expect(find.text('Phổ biến'), findsOneWidget);
      expect(find.text('Không bán chu kỳ này'), findsOneWidget);
      expect(find.text('Giá / tháng'), findsOneWidget);
      expect(find.text('Quyền lợi'), findsOneWidget);
    },
  );
  testWidgets(
    'renewal starts checkout for current plan and can reopen same pending payment',
    (tester) async {
      final billing = Billing();
      final launcher = CheckoutLauncher();
      final cubit = SubscriptionCubit(billing, launcher);
      addTearDown(cubit.close);
      await cubit.refresh();
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const SubscriptionScreen(),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('checkout-1')),
        300,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('checkout-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('checkout-1')));
      await tester.pumpAndSettle();
      expect(billing.calls, contains('checkout:1:MONTHLY'));
      expect(launcher.urls.length, 1);
      await tester.scrollUntilVisible(find.text('Mở lại PayOS'), -300);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mở lại PayOS'));
      await tester.pumpAndSettle();
      expect(launcher.urls.length, 2);
      expect(billing.calls.where((e) => e.startsWith('checkout')).length, 1);
      expect(find.text('Chờ thanh toán'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'expired server flag is shown without locally extending subscription',
    (tester) async {
      final billing = Billing()
        ..onCurrent = () async => SubscriptionModels.subscription({
          ...currentJson(),
          'active': false,
        });
      final cubit = SubscriptionCubit(billing, CheckoutLauncher());
      addTearDown(cubit.close);
      await cubit.refresh();
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const SubscriptionScreen(),
          ),
        ),
      );
      expect(find.text('Không còn hiệu lực'), findsOneWidget);
      expect(
        find.text('Ngày hết hạn: 31/12/2026 (giờ Việt Nam)'),
        findsOneWidget,
      );
    },
  );
}
