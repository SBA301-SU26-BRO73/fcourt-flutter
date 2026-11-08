import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/admin_facility/data/datasources/facility_remote_data_source.dart';
import 'package:fcourt/features/admin_facility/data/repositories/pricing_rule_repository_impl.dart';
import 'package:fcourt/features/admin_facility/domain/entities/clock_time.dart';
import 'package:fcourt/features/admin_facility/domain/entities/pricing_rule.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_adapter.dart';
import '../pricing_fixtures.dart';

({FakeAdapter adapter, PricingRuleRepositoryImpl repo}) _repo(
  FakeHandler handler,
) {
  final adapter = FakeAdapter(handler);
  final dio = Dio(BaseOptions(baseUrl: 'http://facility'))
    ..httpClientAdapter = adapter;
  return (
    adapter: adapter,
    repo: PricingRuleRepositoryImpl(FacilityRemoteDataSource(dio)),
  );
}

Map<String, dynamic> _problem(int status, String detail) => {
  'type': 'about:blank',
  'status': status,
  'detail': detail,
  'instance': '/api/admin/courts/5/pricing-rules',
};

void main() {
  test('GET pricing-rules đọc RuleResponse[] (giá dạng 150000.0)', () async {
    final r = _repo(
      (_) => jsonResponse(200, [
        pricingRuleJson(),
        pricingRuleJson(
          id: 2,
          name: 'Cuối tuần',
          days: [0, 6],
          dayType: 'WEEKEND',
          peak: false,
          price: 200000,
        ),
      ]),
    );

    final rules = await r.repo.getRules(5);

    final request = r.adapter.requests.single;
    expect(
      '${request.method} ${request.path}',
      'GET /api/admin/courts/5/pricing-rules',
    );
    expect(rules, hasLength(2));
    expect(rules.first.pricePerHour, 150000);
    expect(rules.first.startTime, const ClockTime(17, 0));
    expect(rules.last.dayType, PricingDayType.weekend);
  });

  test('POST gửi RuleRequest đúng contract, đọc RuleResponse', () async {
    final r = _repo((_) => jsonResponse(201, pricingRuleJson(id: 9)));

    final created = await r.repo.createRule(
      5,
      samplePricingDraft(name: '  Giờ vàng ', days: const [5, 1, 3]),
    );

    final request = r.adapter.requests.single;
    expect(
      '${request.method} ${request.path}',
      'POST /api/admin/courts/5/pricing-rules',
    );
    expect(request.data, {
      'ruleName': 'Giờ vàng',
      'startTime': '17:00',
      'endTime': '21:00',
      'pricePerHour': 150000,
      'peakHour': true,
      'daysOfWeek': [1, 3, 5],
    });
    expect(created.id, 9);
  });

  test('PUT và DELETE gọi đúng đường dẫn', () async {
    final r = _repo(
      (o) => o.method == 'DELETE'
          ? ResponseBody.fromString('', 204)
          : jsonResponse(200, pricingRuleJson(id: 9)),
    );

    await r.repo.updateRule(5, 9, samplePricingDraft());
    await r.repo.deleteRule(5, 9);

    expect(r.adapter.requests.map((q) => '${q.method} ${q.path}'), [
      'PUT /api/admin/courts/5/pricing-rules/9',
      'DELETE /api/admin/courts/5/pricing-rules/9',
    ]);
  });

  test('copy-weekday-to-weekend gửi hệ số giá (hoặc body rỗng)', () async {
    final r = _repo(
      (_) => jsonResponse(200, [
        pricingRuleJson(days: [0, 6], dayType: 'WEEKEND'),
      ]),
    );

    final copied = await r.repo.copyWeekdayToWeekend(5, multiplier: 1.2);
    await r.repo.copyWeekdayToWeekend(5);

    expect(
      r.adapter.requests.first.path,
      '/api/admin/courts/5/pricing-rules/copy-weekday-to-weekend',
    );
    expect(r.adapter.requests.first.data, {'priceMultiplier': 1.2});
    expect(r.adapter.requests.last.data, <String, dynamic>{});
    expect(copied.single.dayType, PricingDayType.weekend);
  });

  test('lỗi 409 chồng giờ, 400 giờ kết thúc, 404 → tiếng Việt', () async {
    var detail = 'Time range overlaps pricing rule "Peak" on a shared day';
    var status = 409;
    final r = _repo((_) => jsonResponse(status, _problem(status, detail)));

    await expectLater(
      r.repo.createRule(5, samplePricingDraft()),
      throwsA(
        isA<ServerFailure>().having(
          (f) => f.message,
          'message',
          'Khung giờ trùng với một quy tắc giá khác trong cùng nhóm ngày',
        ),
      ),
    );
    status = 400;
    detail = 'endTime must be after startTime';
    await expectLater(
      r.repo.createRule(5, samplePricingDraft()),
      throwsA(
        isA<ServerFailure>().having(
          (f) => f.message,
          'message',
          'Giờ kết thúc phải sau giờ bắt đầu',
        ),
      ),
    );
    status = 404;
    detail = 'Pricing rule not found';
    await expectLater(
      r.repo.deleteRule(5, 1),
      throwsA(isA<ServerFailure>().having((f) => f.statusCode, 'status', 404)),
    );
  });

  test('response sai contract (thiếu peakHour) bị từ chối', () {
    final r = _repo(
      (_) => jsonResponse(200, [
        {...pricingRuleJson()}..remove('peakHour'),
      ]),
    );

    expect(r.repo.getRules(5), throwsA(isA<Failure>()));
  });
}
