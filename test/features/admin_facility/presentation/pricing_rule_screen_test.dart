import 'package:fcourt/app/theme/tokens.dart';
import 'package:fcourt/features/admin_dashboard/presentation/widgets/owner_ui.dart';
import 'package:fcourt/features/admin_facility/domain/entities/clock_time.dart';
import 'package:fcourt/features/admin_facility/domain/entities/pricing_rule.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/court_usecases.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/pricing_usecases.dart';
import 'package:fcourt/features/admin_facility/presentation/bloc/pricing_rule_bloc.dart';
import 'package:fcourt/features/admin_facility/presentation/pages/pricing_rule_config_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fixtures.dart';
import '../mocks.dart';
import '../pricing_fixtures.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

void main() {
  late MockCourtRepository courts;
  late MockPricingRuleRepository pricing;

  setUpAll(registerPricingFallbacks);

  setUp(() {
    courts = MockCourtRepository();
    pricing = MockPricingRuleRepository();
    when(() => courts.getCourt(5)).thenAnswer((_) async => sampleCourt());
  });

  Widget screen(List<PricingRule> rules) {
    when(() => pricing.getRules(5)).thenAnswer((_) async => rules);
    return BlocProvider(
      create: (_) => PricingRuleBloc(
        courtId: 5,
        getCourt: GetCourt(courts),
        getRules: GetPricingRules(pricing),
        saveRule: SavePricingRule(pricing),
        deleteRule: DeletePricingRule(pricing),
        copyToWeekend: CopyWeekdayToWeekend(pricing),
      )..add(const PricingRuleStarted()),
      child: const PricingRuleConfigScreen(),
    );
  }

  final offPeak = samplePricingRule(
    id: 1,
    name: 'Ban ngày',
    start: const ClockTime(6, 0),
    end: const ClockTime(17, 0),
    price: 100000,
    peak: false,
  );
  final peak = samplePricingRule(id: 2);

  testWidgets('dải 24 giờ hiện từng khung kèm giá, tóm tắt biểu giá', (
    tester,
  ) async {
    await _pump(tester, screen([offPeak, peak]));

    expect(find.byKey(const Key('pricing-timeline')), findsOneWidget);
    expect(find.byKey(const Key('pricing-segment-1')), findsOneWidget);
    expect(find.byKey(const Key('pricing-segment-2')), findsOneWidget);
    expect(find.text('100k'), findsOneWidget);
    expect(find.text('150k'), findsOneWidget);
    final peakMaterial = tester.widget<Material>(
      find.byKey(const Key('pricing-segment-2')),
    );
    final offPeakMaterial = tester.widget<Material>(
      find.byKey(const Key('pricing-segment-1')),
    );
    expect(peakMaterial.color, ChartColors.peak);
    expect(offPeakMaterial.color, ChartColors.success);
    expect(find.byKey(const Key('pricing-summary')), findsOneWidget);
    expect(
      find.textContaining('Cao điểm 17:00–21:00: 150.000 đ/giờ'),
      findsOneWidget,
    );
    expect(find.text('Dùng giá mặc định'), findsOneWidget); // cuối tuần trống
  });

  testWidgets('tab cuối tuần chỉ hiện quy tắc T7/CN và nút sao chép', (
    tester,
  ) async {
    final weekend = samplePricingRule(
      id: 3,
      name: 'Cuối tuần',
      days: weekendDays,
      price: 200000,
      peak: false,
      start: const ClockTime(6, 0),
      end: const ClockTime(22, 0),
    );
    await _pump(tester, screen([peak, weekend]));
    expect(find.byKey(const Key('pricing-rule-2')), findsOneWidget);
    expect(find.byKey(const Key('pricing-rule-3')), findsNothing);

    await tester.tap(find.byKey(const Key('tab-weekend')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pricing-rule-3')), findsOneWidget);
    expect(find.byKey(const Key('pricing-rule-2')), findsNothing);
    expect(find.byKey(const Key('copy-to-weekend')), findsOneWidget);
  });

  testWidgets('chưa có quy tắc: báo dùng giá mặc định', (tester) async {
    await _pump(tester, screen(const []));

    expect(find.byKey(const Key('pricing-empty')), findsOneWidget);
  });

  testWidgets('thêm khung giá qua BottomSheet gửi đúng ngày T2–T6', (
    tester,
  ) async {
    when(() => pricing.createRule(5, any()))
        .thenAnswer((_) async => samplePricingRule(id: 9));
    await _pump(tester, screen(const []));

    await tester.tap(find.byKey(const Key('add-weekday-rule')));
    await tester.pumpAndSettle();
    final save = find.byKey(const Key('pricing-save'));
    expect(tester.widget<ButtonStyleButton>(save).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('pricing-price')), '150000');
    await tester.pumpAndSettle();
    expect(tester.widget<ButtonStyleButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await tester.pumpAndSettle();

    verify(
      () => pricing.createRule(
        5,
        samplePricingDraft(name: 'Giờ cao điểm', days: weekdayDays),
      ),
    ).called(1);
  });

  testWidgets('BottomSheet báo chồng lấn và không cho lưu', (tester) async {
    await _pump(tester, screen([peak]));

    await tester.tap(find.byKey(const Key('add-weekday-rule')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('pricing-price')), '120000');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pricing-sheet-warning')), findsOneWidget);
    expect(find.textContaining('trùng'), findsWidgets);
    expect(
      tester
          .widget<ButtonStyleButton>(find.byKey(const Key('pricing-save')))
          .onPressed,
      isNull,
    );
    verifyNever(() => pricing.createRule(any(), any()));
  });

  testWidgets('giờ kết thúc sớm hơn giờ bắt đầu: báo lỗi, chặn lưu', (
    tester,
  ) async {
    await _pump(tester, screen(const []));
    await tester.tap(find.byKey(const Key('add-weekday-rule')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('pricing-price')), '120000');

    // Đổi giờ kết thúc về 16:00 (sớm hơn 17:00) bằng TimePicker nhập số.
    await tester.tap(find.byKey(const Key('pricing-end')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(fields.evaluate().length - 2), '16');
    await tester.enterText(fields.at(fields.evaluate().length - 1), '00');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pricing-sheet-warning')), findsOneWidget);
    expect(find.textContaining('sớm hơn'), findsOneWidget);
    expect(
      tester
          .widget<ButtonStyleButton>(find.byKey(const Key('pricing-save')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('sao chép sang cuối tuần gửi hệ số +10%', (tester) async {
    when(() => pricing.copyWeekdayToWeekend(5, multiplier: 1.1))
        .thenAnswer((_) async => const []);
    await _pump(tester, screen([peak]));
    await tester.tap(find.byKey(const Key('tab-weekend')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('copy-to-weekend')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('copy-percent')), '10');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('copy-confirm')));
    await tester.pumpAndSettle();

    verify(() => pricing.copyWeekdayToWeekend(5, multiplier: 1.1)).called(1);
  });

  testWidgets('nút sao chép bị khóa khi chưa có quy tắc ngày thường', (
    tester,
  ) async {
    await _pump(tester, screen(const []));
    await tester.tap(find.byKey(const Key('tab-weekend')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<OwnerPillButton>(find.byKey(const Key('copy-to-weekend')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('xóa khung giá hỏi xác nhận rồi gọi API', (tester) async {
    when(() => pricing.deleteRule(5, 2)).thenAnswer((_) async {});
    await _pump(tester, screen([peak]));

    await tester.tap(find.byTooltip('Xóa khung giá'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa khung giá?'), findsOneWidget);
    verifyNever(() => pricing.deleteRule(any(), any()));
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
    await tester.pumpAndSettle();

    verify(() => pricing.deleteRule(5, 2)).called(1);
  });
}
