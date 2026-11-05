import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/vouchers/data/voucher_repository_impl.dart';
import 'package:fcourt/features/vouchers/data/voucher_model.dart';
import 'package:fcourt/features/vouchers/domain/voucher.dart';
import 'package:fcourt/features/vouchers/domain/voucher_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

Map<String, dynamic> voucherJson({
  int id = 1,
  int branchId = 1,
  String status = 'ACTIVE',
}) => {
  'id': id,
  'branchId': branchId,
  'code': 'SAVE$id',
  'discountType': 'PERCENTAGE',
  'discountValue': 12.5,
  'maxDiscountAmount': 50000.25,
  'minOrderAmount': 100000,
  'startDate': '2099-11-04T17:00:00Z',
  'endDate': '2099-11-10T17:00:00Z',
  'usageLimit': 10,
  'usedCount': 2,
  'status': status,
};
Voucher voucher({int id = 1, int branchId = 1}) =>
    VoucherModel.parse(voucherJson(id: id, branchId: branchId), branchId);

void main() {
  test('duplicate code is localized while auth and service failures remain actionable', () async {
    var status = 409;
    final repository = VoucherRepositoryImpl(
      Dio()
        ..httpClientAdapter = FakeAdapter(
          (_) => jsonResponse(status, {'detail': 'Error'}),
        ),
    );
    await expectLater(
      repository.save(VoucherDraft.fromVoucher(voucher())),
      throwsA(
        isA<ServerFailure>().having(
          (e) => e.message,
          'message',
          contains('đã tồn tại'),
        ),
      ),
    );
    status = 401;
    await expectLater(repository.list(1), throwsA(isA<UnauthorizedFailure>()));
    for (final code in [403, 503]) {
      status = code;
      await expectLater(
        repository.list(1),
        throwsA(isA<ServerFailure>().having((e) => e.statusCode, 'code', code)),
      );
    }
  });
  test(
    'cross-branch invalid voucher data fails closed',
    () async {
      for (final change in <Map<String, dynamic>>[
        {'branchId': 2},
        {'id': -1},
        {'discountValue': -1},
        {'discountValue': 101},
        {'usedCount': 11},
        {'status': 'PAUSED'},
        {'startDate': '2099-11-04T17:00:00'},
        {'endDate': '2099-01-01T00:00:00Z'},
      ]) {
        final repository = VoucherRepositoryImpl(
          Dio()
            ..httpClientAdapter = FakeAdapter(
              (_) => jsonResponse(200, {
                'items': [
                  {...voucherJson(), ...change},
                ],
                'page': 0,
                'size': 20,
                'total': 1,
              }),
            ),
        );
        await expectLater(repository.list(1), throwsA(isA<UnknownFailure>()));
      }
    },
  );
  test('activation gets latest details before full replacement and cannot revive expired dates', () async {
    var expired = false;
    final adapter = FakeAdapter(
      (r) => jsonResponse(200, {
        ...voucherJson(
          status: r.method == 'PUT'
              ? (r.data as Map)['status'] as String
              : 'ACTIVE',
        ),
        'usedCount': 7,
        if (expired) 'endDate': '2020-01-01T00:00:00Z',
        if (expired) 'startDate': '2019-01-01T00:00:00Z',
      }),
    );
    final repository = VoucherRepositoryImpl(
      Dio()..httpClientAdapter = adapter,
    );
    final disabled = await repository.setEnabled(1, 1, false);
    expect(adapter.requests.map((r) => r.method), ['GET', 'PUT']);
    expect((adapter.requests.last.data as Map)['status'], 'EXPIRED');
    expect(
      (adapter.requests.last.data as Map).containsKey('usedCount'),
      isFalse,
    );
    expect(disabled.status, VoucherStatus.expired);
    expired = true;
    await expectLater(
      repository.setEnabled(1, 1, true),
      throwsA(isA<ServerFailure>()),
    );
    expect(adapter.requests.last.method, 'GET');
    expect(adapter.requests.length, 3);
  });
  test(
    'list and CRUD map exact scoped contract and full decimal body',
    () async {
      final adapter = FakeAdapter(
        (r) => jsonResponse(
          r.method == 'POST' ? 201 : 200,
          r.method == 'GET' && r.path == '/api/admin/vouchers'
              ? {
                  'items': [voucherJson()],
                  'page': 0,
                  'size': 20,
                  'total': 1,
                }
              : voucherJson(),
        ),
      );
      final repository = VoucherRepositoryImpl(
        Dio(BaseOptions(headers: {'Authorization': 'Bearer fixture'}))
          ..httpClientAdapter = adapter,
      );
      final page = await repository.list(1);
      expect(adapter.requests.single.queryParameters, {
        'branchId': 1,
        'page': 0,
        'size': 20,
      });
      expect(page.items.single.valueMinor, 1250);
      expect(page.items.single.capMinor, 5000025);
      final draft = VoucherDraft.fromVoucher(page.items.single);
      await repository.save(draft);
      expect(adapter.requests.last.method, 'POST');
      expect(adapter.requests.last.data, {
        'code': 'SAVE1',
        'branchId': 1,
        'discountType': 'PERCENTAGE',
        'discountValue': '12.50',
        'maxDiscountAmount': '50000.25',
        'minOrderAmount': '100000.00',
        'startDate': '2099-11-04T17:00:00.000Z',
        'endDate': '2099-11-10T17:00:00.000Z',
        'usageLimit': 10,
        'status': 'ACTIVE',
      });
      await repository.save(draft, id: 1, usedCount: 2);
      expect(adapter.requests.last.path, '/api/admin/vouchers/1');
      expect(adapter.requests.last.method, 'PUT');
      expect(adapter.requests.last.extra['skipAuth'], isNot(true));
      expect(adapter.requests.last.headers['Authorization'], 'Bearer fixture');
    },
  );
}
