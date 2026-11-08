import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/vouchers/data/voucher_usage_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

Map<String, dynamic> usageJson() => {
  'id': '00000000-0000-0000-0000-000000000001',
  'voucherId': 1,
  'bookingId': 2,
  'userId': 3,
  'discountAmount': 1234.56,
  'usedAt': '2026-11-05T01:00:00Z',
  'usedAtSource': 'PAYMENT_CONFIRMED',
};
Map<String, dynamic> usagePage(List<dynamic> items) => {
  'items': items,
  'page': 0,
  'size': 20,
  'total': 100,
  'totalDiscountAmount': 500000,
};
void main() {
  phoneSearchTests();
  test(
    'legacy API preserves global aggregate and absent customer snapshots',
    () async {
      final repo = VoucherUsageRepositoryImpl(
        Dio()
          ..httpClientAdapter = FakeAdapter((r) {
            expect(r.path, '/api/admin/vouchers/1/usages');
            expect(r.queryParameters, {'page': 0, 'size': 20});
            return jsonResponse(200, usagePage([usageJson()]));
          }),
      );
      final page = await repo.list(1);
      expect(page.totalDiscountMinor, 50000000);
      expect(page.items.single.discountMinor, 123456);
      expect(page.items.single.customerPhone, isNull);
      expect(page.hasMore, isTrue);
    },
  );
  test('ignored phone query fails instead of showing unrelated rows', () async {
    final repo = VoucherUsageRepositoryImpl(
      Dio()
        ..httpClientAdapter = FakeAdapter(
          (_) => jsonResponse(200, usagePage([usageJson()])),
        ),
    );
    await expectLater(
      repo.list(1, search: '090123'),
      throwsA(isA<ServerFailure>()),
    );
  });
  test(
    'optional customer snapshots support normalized server search',
    () async {
      final repo = VoucherUsageRepositoryImpl(
        Dio()
          ..httpClientAdapter = FakeAdapter((r) {
            expect(r.queryParameters['phone'], '090123');
            return jsonResponse(
              200,
              usagePage([
                {
                  ...usageJson(),
                  'customerName': 'An',
                  'customerPhone': '090 123 4567',
                  'bookingCode': 'FC-2',
                },
              ]),
            );
          }),
      );
      expect(
        (await repo.list(1, search: '090 123')).items.single.bookingCode,
        'FC-2',
      );
    },
  );
  test(
    'malformed money, scope, timestamps and duplicate bookings fail closed',
    () async {
      for (final change in [
        {'voucherId': 9},
        {'discountAmount': -1},
        {'discountAmount': 1.001},
        {'usedAt': '2026-11-05T01:00:00'},
        {'usedAtSource': 'UNKNOWN'},
        {'userId': 0},
      ]) {
        final repo = VoucherUsageRepositoryImpl(
          Dio()
            ..httpClientAdapter = FakeAdapter(
              (_) => jsonResponse(
                200,
                usagePage([
                  {...usageJson(), ...change},
                ]),
              ),
            ),
        );
        await expectLater(repo.list(1), throwsA(isA<UnknownFailure>()));
      }
      final repo = VoucherUsageRepositoryImpl(
        Dio()
          ..httpClientAdapter = FakeAdapter(
            (_) => jsonResponse(200, usagePage([usageJson(), usageJson()])),
          ),
      );
      await expectLater(repo.list(1), throwsA(isA<UnknownFailure>()));
    },
  );
  test('authorization remains actionable', () async {
    for (final status in [401, 403, 404, 503]) {
      final repo = VoucherUsageRepositoryImpl(
        Dio()
          ..httpClientAdapter = FakeAdapter(
            (_) => jsonResponse(status, {'detail': 'Error'}),
          ),
      );
      await expectLater(
        repo.list(1),
        throwsA(
          status == 401 ? isA<UnauthorizedFailure>() : isA<ServerFailure>(),
        ),
      );
    }
  });
}

void phoneSearchTests() {
  test(
    'country-code phone is normalized like the server and matched by prefix',
    () async {
      final repo = VoucherUsageRepositoryImpl(
        Dio()
          ..httpClientAdapter = FakeAdapter((r) {
            expect(r.queryParameters['phone'], '0912345');
            return jsonResponse(
              200,
              usagePage([
                {
                  ...usageJson(),
                  'customerName': 'An',
                  'customerPhone': '+84 912 345 678',
                },
              ]),
            );
          }),
      );
      final page = await repo.list(1, search: '+84 912 345');
      expect(page.items.single.customerPhone, '+84 912 345 678');
    },
  );
  test('phone shorter than 3 digits or longer than 15 is rejected before any request', () async {
    final repo = VoucherUsageRepositoryImpl(
      Dio()..httpClientAdapter = FakeAdapter((_) => fail('must not call API')),
    );
    for (final bad in ['09', 'abc', '1' * 16]) {
      await expectLater(
        repo.list(1, search: bad),
        throwsA(isA<ServerFailure>()),
      );
    }
  });
  test(
    'server rows that do not match the searched prefix are rejected',
    () async {
      final repo = VoucherUsageRepositoryImpl(
        Dio()
          ..httpClientAdapter = FakeAdapter(
            (_) => jsonResponse(
              200,
              usagePage([
                {...usageJson(), 'customerPhone': '0987654321'},
              ]),
            ),
          ),
      );
      await expectLater(
        repo.list(1, search: '0912'),
        throwsA(isA<ServerFailure>()),
      );
    },
  );
}
