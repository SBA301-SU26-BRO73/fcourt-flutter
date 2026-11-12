import 'package:fcourt/features/admin_facility/domain/entities/clock_time.dart';
import 'package:fcourt/features/admin_facility/domain/entities/court.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/branch_usecases.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/court_usecases.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/pricing_usecases.dart';
import 'package:fcourt/features/admin_facility/presentation/bloc/court_list_bloc.dart';
import 'package:fcourt/features/admin_facility/presentation/bloc/pricing_rule_bloc.dart';
import 'package:fcourt/features/admin_facility/presentation/pages/court_list_screen.dart';
import 'package:fcourt/features/admin_facility/presentation/pages/pricing_rule_config_screen.dart';
import 'package:fcourt/features/staff/presentation/staff_page.dart';
import 'package:fcourt/features/subscription/presentation/subscription_cubit.dart';
import 'package:fcourt/features/subscription/presentation/subscription_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/owner_shot.dart';
import 'admin_facility/fixtures.dart';
import 'admin_facility/mocks.dart';
import 'admin_facility/pricing_fixtures.dart';
import 'staff/staff_test.dart' as staff;
import 'subscription/fixtures.dart';

void main() {
  setUpAll(registerPricingFallbacks);

  for (final b in Brightness.values) {
    testWidgets('court list (${b.name})', (tester) async {
      final branches = MockBranchRepository();
      final courts = MockCourtRepository();
      final types = MockCourtTypeRepository();
      when(
        () => branches.getBranches(),
      ).thenAnswer((_) async => [sampleBranch(name: 'Sân Cầu Lông Ba Đình')]);
      when(() => types.getCourtTypes())
          .thenAnswer((_) async => sampleCourtTypes);
      when(() => courts.getCourts(1)).thenAnswer(
        (_) async => [
          sampleCourt(),
          sampleCourt(id: 6, status: CourtStatus.maintenance),
        ],
      );
      await pumpOwner(
        tester,
        b,
        BlocProvider(
          create: (_) => CourtListBloc(
            getBranches: GetBranches(branches),
            getCourts: GetCourts(courts),
            getCourtTypes: GetCourtTypes(types),
            toggleMaintenance: ToggleCourtMaintenance(courts),
          )..add(const CourtListStarted(1)),
          child: CourtListScreen(
            onCreateCourt: (_) async => null,
            onEditCourt: (_) async => null,
            onOpenSlotTemplate: (_) {},
            onOpenPricing: (_) {},
            onOpenCalendar: (_) {},
          ),
        ),
        navIndex: 2,
        withBack: true,
        shot: 'owner-courts',
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Thêm sân'), findsOneWidget);
    });

    testWidgets('pricing rules (${b.name})', (tester) async {
      final courts = MockCourtRepository();
      final pricing = MockPricingRuleRepository();
      when(() => courts.getCourt(5)).thenAnswer((_) async => sampleCourt());
      when(() => pricing.getRules(5)).thenAnswer(
        (_) async => [
          samplePricingRule(),
          samplePricingRule(
            id: 2,
            name: 'Giờ thấp điểm',
            start: const ClockTime(6, 0),
            end: const ClockTime(17, 0),
            price: 90000,
            peak: false,
          ),
        ],
      );
      await pumpOwner(
        tester,
        b,
        BlocProvider(
          create: (_) => PricingRuleBloc(
            courtId: 5,
            getCourt: GetCourt(courts),
            getRules: GetPricingRules(pricing),
            saveRule: SavePricingRule(pricing),
            deleteRule: DeletePricingRule(pricing),
            copyToWeekend: CopyWeekdayToWeekend(pricing),
          )..add(const PricingRuleStarted()),
          child: const PricingRuleConfigScreen(),
        ),
        navIndex: 2,
        withBack: true,
        shot: 'owner-pricing',
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Tóm tắt biểu giá'), findsOneWidget);
    });

    testWidgets('staff (${b.name})', (tester) async {
      await pumpOwner(
        tester,
        b,
        StaffPage(repository: staff.FakeStaff()),
        nav: true,
        navIndex: 2,
        withBack: true,
        shot: 'owner-staff',
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Khóa tài khoản'), findsOneWidget);
    });

    testWidgets('subscription (${b.name})', (tester) async {
      final cubit = SubscriptionCubit(Billing(), CheckoutLauncher());
      addTearDown(cubit.close);
      await cubit.refresh();
      await pumpOwner(
        tester,
        b,
        BlocProvider.value(value: cubit, child: const SubscriptionScreen()),
        navIndex: 2,
        withBack: true,
        shot: 'owner-subscription',
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Gói hiện tại'), findsOneWidget);
    });
  }
}
