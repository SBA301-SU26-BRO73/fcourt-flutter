import 'package:dio/dio.dart';
import 'package:fcourt/features/promos/data/promo_repository_impl.dart';
import 'package:fcourt/features/promos/domain/booking_promo.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

const applicationId = '12345678-1234-1234-1234-123456789012';
Map<String, dynamic> snapshotJson({bool applied = false}) => {
  'id': 42,
  'totalPrice': applied ? 120000 : 160000,
  'originalAmount': applied ? 160000 : null,
  'discountAmount': applied ? 40000 : null,
  'voucherApplicationId': applied ? applicationId : null,
  'paymentFrozen': false,
  'status': 'PENDING_PAYMENT',
  'holdExpiresAt': '2099-01-01T00:00:00Z',
};
Map<String, dynamic> applyJson() => {
  'applicationId': applicationId,
  'voucherId': 1,
  'bookingId': 42,
  'originalAmount': 160000,
  'discountAmount': 40000,
  'finalAmount': 120000,
  'expiresAt': '2099-01-01T00:00:00Z',
};

void main() {
  test(
    'invalid money arithmetic identities and snapshot metadata fail closed',
    () async {
      for (final change in <Map<String, dynamic>>[
        {'bookingId': 99},
        {'applicationId': 'invalid'},
        {'discountAmount': -1},
        {'finalAmount': 120001},
        {'originalAmount': 160001},
        {'discountAmount': .001},
      ]) {
        final repository = PromoRepositoryImpl(
          Dio(),
          Dio()
            ..httpClientAdapter = FakeAdapter(
              (_) => jsonResponse(200, {...applyJson(), ...change}),
            ),
        );
        await expectLater(
          repository.apply(42, 'SAVE', 16000000),
          throwsA(
            isA<PromoFailure>().having((e) => e.uncertain, 'uncertain', isTrue),
          ),
        );
      }
      final repository = PromoRepositoryImpl(
        Dio()
          ..httpClientAdapter = FakeAdapter(
            (_) => jsonResponse(200, {
              ...snapshotJson(applied: true),
              'totalPrice': 0,
            }),
          ),
        Dio(),
      );
      await expectLater(repository.snapshot(42), throwsA(isA<PromoFailure>()));
    },
  );
  test('apply sends original amount and JWT while snapshot never substitutes guest token', () async {
    final apiAdapter = FakeAdapter(
      (_) => jsonResponse(200, snapshotJson(applied: true)),
    );
    final voucherAdapter = FakeAdapter((_) => jsonResponse(200, applyJson()));
    final repository = PromoRepositoryImpl(
      Dio(BaseOptions(headers: {'Authorization': 'Bearer customer'}))
        ..httpClientAdapter = apiAdapter,
      Dio(BaseOptions(headers: {'Authorization': 'Bearer customer'}))
        ..httpClientAdapter = voucherAdapter,
    );
    final result = await repository.apply(42, ' save_25 ', 16000000);
    expect(voucherAdapter.requests.single.path, '/api/vouchers/apply');
    expect(voucherAdapter.requests.single.data, {
      'code': 'SAVE_25',
      'bookingId': 42,
      'totalAmount': '160000.00',
    });
    expect(
      voucherAdapter.requests.single.headers['Authorization'],
      'Bearer customer',
    );
    expect(
      voucherAdapter.requests.single.headers.containsKey('X-Hold-Token'),
      isFalse,
    );
    final snapshot = await repository.snapshot(42);
    expect(snapshot.originalMinor, result.originalMinor);
    expect(snapshot.finalMinor, 12000000);
    expect(apiAdapter.requests.single.path, '/api/bookings/42');
    expect(
      apiAdapter.requests.single.headers.containsKey('X-Hold-Token'),
      isFalse,
    );
  });
}
