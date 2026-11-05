import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/admin_facility/domain/entities/clock_time.dart';
import 'package:fcourt/features/admin_facility/domain/entities/pricing_rule.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/court_usecases.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/pricing_usecases.dart';
import 'package:fcourt/features/admin_facility/presentation/bloc/pricing_rule_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fixtures.dart';
import '../mocks.dart';
import '../pricing_fixtures.dart';

void main() {
  late MockCourtRepository courts;
  late MockPricingRuleRepository pricing;

  setUpAll(registerPricingFallbacks);

  setUp(() {
    courts = MockCourtRepository();
    pricing = MockPricingRuleRepository();
    when(() => courts.getCourt(5)).thenAnswer((_) async => sampleCourt());
    when(() => pricing.getRules(5)).thenAnswer((_) async => const []);
  });

  PricingRuleBloc build() => PricingRuleBloc(
    courtId: 5,
    getCourt: GetCourt(courts),
    getRules: GetPricingRules(pricing),
    saveRule: SavePricingRule(pricing),
    deleteRule: DeletePricingRule(pricing),
    copyToWeekend: CopyWeekdayToWeekend(pricing),
  );

  Future<PricingRuleBloc> ready([List<PricingRule>? rules]) async {
    if (rules != null) {
      when(() => pricing.getRules(5)).thenAnswer((_) async => rules);
    }
    final bloc = build()..add(const PricingRuleStarted());
    await bloc.stream.firstWhere((s) => s.status == PricingRuleStatus.ready);
    return bloc;
  }

  test('tải sân và danh sách quy tắc', () async {
    final rule = samplePricingRule();

    final bloc = await ready([rule]);

    expect(bloc.state.court, sampleCourt());
    expect(bloc.state.rules, [rule]);
  });

  test('tải lỗi → loadFailure kèm thông báo', () async {
    when(() => pricing.getRules(5)).thenThrow(const NetworkFailure());
    final bloc = build()..add(const PricingRuleStarted());

    final state = await bloc.stream.firstWhere(
      (s) => s.status == PricingRuleStatus.loadFailure,
    );

    expect(state.message, 'Không kết nối được máy chủ');
  });

  test('lưu quy tắc mới → gọi API rồi nạp lại danh sách', () async {
    final saved = samplePricingRule(id: 7);
    when(() => pricing.createRule(5, any())).thenAnswer((_) async => saved);
    final bloc = await ready([]);
    when(() => pricing.getRules(5)).thenAnswer((_) async => [saved]);

    bloc.add(PricingRuleSaved(samplePricingDraft()));
    final state = await bloc.stream.firstWhere(
      (s) => !s.busy && s.notice != null,
    );

    expect(state.rules, [saved]);
    expect(state.notice!.message, 'Đã thêm khung giá');
    expect(state.notice!.isError, isFalse);
    verify(() => pricing.createRule(5, samplePricingDraft())).called(1);
  });

  test('sửa quy tắc có sẵn không bị coi là chồng lấn với chính nó', () async {
    final existing = samplePricingRule(id: 7);
    when(() => pricing.updateRule(5, 7, any()))
        .thenAnswer((_) async => existing);
    final bloc = await ready([existing]);

    bloc.add(PricingRuleSaved(samplePricingDraft(price: 160000), ruleId: 7));
    final state = await bloc.stream.firstWhere(
      (s) => !s.busy && s.notice != null,
    );

    expect(state.notice!.message, 'Đã cập nhật khung giá');
    verify(() => pricing.updateRule(5, 7, any())).called(1);
  });

  test('giờ kết thúc sớm hơn giờ bắt đầu → báo lỗi, không gọi API', () async {
    final bloc = await ready();

    bloc.add(
      PricingRuleSaved(
        samplePricingDraft(
          start: const ClockTime(21, 0),
          end: const ClockTime(17, 0),
        ),
      ),
    );
    final state = await bloc.stream.firstWhere((s) => s.notice != null);

    expect(state.notice!.isError, isTrue);
    expect(
      state.notice!.message,
      'Giờ kết thúc đang sớm hơn (hoặc bằng) giờ bắt đầu',
    );
    verifyNever(() => pricing.createRule(any(), any()));
  });

  test('khung giờ chồng lấn → báo lỗi, không gọi API', () async {
    final bloc = await ready([samplePricingRule()]);

    bloc.add(
      PricingRuleSaved(
        samplePricingDraft(
          name: 'Trùng',
          start: const ClockTime(20, 0),
          end: const ClockTime(22, 0),
        ),
      ),
    );
    final state = await bloc.stream.firstWhere((s) => s.notice != null);

    expect(state.notice!.isError, isTrue);
    expect(state.notice!.message, contains('trùng'));
    verifyNever(() => pricing.createRule(any(), any()));
  });

  test('máy chủ từ chối (409) → giữ nguyên danh sách, hiện lỗi', () async {
    when(() => pricing.createRule(5, any()))
        .thenThrow(const ServerFailure('Khung giờ trùng', statusCode: 409));
    final existing = samplePricingRule(id: 1, days: weekendDays);
    final bloc = await ready([existing]);

    bloc.add(PricingRuleSaved(samplePricingDraft()));
    final state = await bloc.stream.firstWhere(
      (s) => !s.busy && s.notice != null,
    );

    expect(state.rules, [existing]);
    expect(state.notice!.isError, isTrue);
    expect(state.notice!.message, 'Khung giờ trùng');
  });

  test('xóa quy tắc', () async {
    when(() => pricing.deleteRule(5, 1)).thenAnswer((_) async {});
    final bloc = await ready([samplePricingRule()]);
    when(() => pricing.getRules(5)).thenAnswer((_) async => const []);

    bloc.add(const PricingRuleDeleted(1));
    final state = await bloc.stream.firstWhere(
      (s) => !s.busy && s.notice != null,
    );

    expect(state.rules, isEmpty);
    expect(state.notice!.message, 'Đã xóa khung giá');
  });

  test('sao chép sang cuối tuần gửi hệ số giá rồi nạp lại', () async {
    final weekend = samplePricingRule(id: 8, days: weekendDays, price: 180000);
    when(() => pricing.copyWeekdayToWeekend(5, multiplier: 1.2))
        .thenAnswer((_) async => [weekend]);
    final bloc = await ready([samplePricingRule()]);
    when(() => pricing.getRules(5))
        .thenAnswer((_) async => [samplePricingRule(), weekend]);

    bloc.add(const PricingRuleCopyToWeekendRequested(multiplier: 1.2));
    final state = await bloc.stream.firstWhere(
      (s) => !s.busy && s.notice != null,
    );

    expect(state.rules, hasLength(2));
    expect(state.notice!.message, 'Đã sao chép cấu hình sang cuối tuần');
    verify(() => pricing.copyWeekdayToWeekend(5, multiplier: 1.2)).called(1);
  });
}
