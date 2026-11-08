import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/core/config/app_config.dart';
import 'package:fcourt/features/subscription/data/subscription_models.dart';
import 'package:fcourt/features/subscription/data/subscription_repository_impl.dart';
import 'package:fcourt/features/subscription/domain/subscription.dart';

import '../../helpers/fake_adapter.dart';
import 'fixtures.dart';

void main() {
  test(
    'catalog honors backend popularity nullable prices and integer VND',
    () async {
      final repo = SubscriptionRepositoryImpl(
        Dio()
          ..httpClientAdapter = FakeAdapter((r) {
            expect(r.path, '/api/subscription-plans/all');
            return jsonResponse(200, [
              {...planJson(), 'monthlyPrice': null},
              planJson(id: 2, popular: true),
            ]);
          }),
      );
      final plans = await repo.plans();
      expect(plans.first.monthlyPrice, isNull);
      expect(plans.first.popular, isFalse);
      expect(plans.last.popular, isTrue);
      expect(plans.last.monthlyPrice, 100000);
    },
  );
  test(
    'current subscription uses snapshot limits and server active flag',
    () async {
      final repo = SubscriptionRepositoryImpl(
        Dio()
          ..httpClientAdapter = FakeAdapter((r) {
            expect(r.path, '/api/subscriptions/my-subscription');
            return jsonResponse(200, {...currentJson(), 'active': false});
          }),
      );
      final current = await repo.current();
      expect(current.period.maxBranches, 1);
      expect(current.period.plan.maxBranches, 3);
      expect(current.active, isFalse);
    },
  );
  test(
    'checkout sends only plan and cycle and status request verifies identity',
    () async {
      final repo = SubscriptionRepositoryImpl(
        Dio()
          ..httpClientAdapter = FakeAdapter((r) {
            if (r.method == 'POST') {
              expect(r.path, '/api/subscriptions/checkout');
              expect(r.data, {'planId': 2, 'billingCycle': 'YEARLY'});
            } else {
              expect(r.path, '/api/subscriptions/payments/123456');
            }
            return jsonResponse(200, {
              ...paymentJson(),
              'billingCycle': 'YEARLY',
            });
          }),
      );
      expect(
        (await repo.checkout(2, BillingCycle.yearly)).cycle,
        BillingCycle.yearly,
      );
      expect((await repo.payment(123456)).orderCode, 123456);
    },
  );
  test('queued paid periods are preserved with their own snapshot limits', () {
    final current = SubscriptionModels.subscription({
      ...currentJson(),
      'upcoming': [
        {
          'id': 11,
          'plan': planJson(id: 2),
          'maxBranches': 4,
          'maxCourts': 20,
          'startDate': '2027-01-01',
          'endDate': '2027-12-31',
        },
      ],
    });
    expect(current.period.plan.id, 1);
    expect(current.upcoming.single.plan.id, 2);
    expect(current.upcoming.single.maxBranches, 4);
  });
  test('malformed calendar dates and overlapping periods fail closed', () {
    for (final change in [
      {'startDate': '2026-02-30'},
      {'endDate': '2025-12-31'},
      {'active': 'true'},
      {
        'upcoming': [
          {
            'id': 11,
            'plan': planJson(id: 2),
            'maxBranches': 4,
            'maxCourts': 20,
            'startDate': '2026-12-31',
            'endDate': '2027-12-31',
          },
        ],
      },
    ]) {
      expect(
        () => SubscriptionModels.subscription({...currentJson(), ...change}),
        throwsFormatException,
      );
    }
  });
  test('unsafe prices and invented plan flags are rejected', () async {
    for (final change in [
      {'monthlyPrice': 100.5},
      {'yearlyPrice': 0},
      {'popular': null},
      {'maxCourts': 0},
      {
        'features': [123],
      },
      {'id': -1},
      {'monthlyPrice': 9007199254740992},
    ]) {
      final repo = SubscriptionRepositoryImpl(
        Dio()
          ..httpClientAdapter = FakeAdapter(
            (_) => jsonResponse(200, [
              {...planJson(), ...change},
            ]),
          ),
      );
      await expectLater(repo.plans(), throwsA(isA<UnknownFailure>()));
    }
  });
  test(
    'PayOS links cannot point to credentials another host scheme or port',
    () {
      for (final url in [
        'http://pay.payos.vn/web/a',
        'https://pay.payos.vn.evil.test/web/a',
        'https://evil.test/web/a',
        'https://user:pass@pay.payos.vn/web/a',
        'https://pay.payos.vn:444/web/a',
        'javascript:alert(1)',
      ]) {
        expect(
          () => SubscriptionModels.payment({
            ...paymentJson(),
            'checkoutUrl': url,
          }),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'unknown or inconsistent payment states and mismatched orders fail closed',
    () async {
      for (final change in [
        {'status': 'SUCCESS'},
        {'status': 'PAID', 'subscriptionActive': true, 'paidAt': null},
        {'subscriptionActive': true},
        {'amount': -1},
        {'orderCode': 123457},
      ]) {
        final repo = SubscriptionRepositoryImpl(
          Dio()
            ..httpClientAdapter = FakeAdapter(
              (_) => jsonResponse(200, {...paymentJson(), ...change}),
            ),
        );
        await expectLater(repo.payment(123456), throwsA(isA<UnknownFailure>()));
      }
    },
  );
  test('auth ownership and gateway failures stay actionable', () async {
    for (final status in [401, 403, 404, 409, 502, 503]) {
      final repo = SubscriptionRepositoryImpl(
        Dio()
          ..httpClientAdapter = FakeAdapter(
            (_) => jsonResponse(status, {'detail': 'Error'}),
          ),
      );
      await expectLater(
        repo.current(),
        throwsA(
          status == 401
              ? isA<UnauthorizedFailure>()
              : isA<ServerFailure>().having(
                  (e) => e.statusCode,
                  'status',
                  status,
                ),
        ),
      );
    }
  });
  test('subscription URL supports direct service and blank fallback', () {
    expect(
      const AppConfig(
        env: AppEnv.dev,
        apiBaseUrl: 'http://api',
      ).subscriptionUrl,
      'http://api',
    );
    expect(
      const AppConfig(
        env: AppEnv.dev,
        apiBaseUrl: 'http://api',
        subscriptionBaseUrl: ' ',
      ).subscriptionUrl,
      'http://api',
    );
    expect(
      const AppConfig(
        env: AppEnv.dev,
        apiBaseUrl: 'http://api',
        subscriptionBaseUrl: 'http://billing',
      ).subscriptionUrl,
      'http://billing',
    );
  });
}
