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
