import 'package:fcourt/features/vouchers/domain/voucher.dart';
import 'package:fcourt/features/vouchers/domain/voucher_draft.dart';
import 'package:fcourt/features/vouchers/data/voucher_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repository_test.dart' show voucher;

void main() {
  test('draft validation rejects negative money over-100 percent and insufficient usage', () {
    VoucherDraft draft({
      String code = 'SAVE',
      String value = '10',
      String cap = '',
      String minimum = '0',
      String limit = '10',
    }) => VoucherDraft(
      branchId: 1,
      code: code,
      type: VoucherDiscountType.percentage,
      value: value,
      cap: cap,
      minimum: minimum,
      limit: limit,
      startsAt: DateTime.utc(2099),
      endsAt: DateTime.utc(2100),
    );
    for (final invalid in [
      draft(value: '-1'),
      draft(value: '0'),
      draft(value: '100.01'),
      draft(cap: '-1'),
      draft(cap: '0'),
      draft(minimum: '-1'),
      draft(value: '0.001'),
      draft(code: 'INVALID CODE'),
      draft(limit: '1'),
      draft(limit: '2147483648'),
    ]) {
      expect(invalid.errors(usedCount: 2), isNotEmpty);
    }
    expect(
      draft(
        code: ' lower_case ',
        value: '12.50',
        minimum: '0',
        cap: '100000.25',
      ).errors(),
      isEmpty,
    );
    expect(draft(value: '100').errors(), isEmpty);
  });
  test(
    'edit round trip preserves stored instants decimals and usage constraints',
    () {
      final row = voucher();
      final draft = VoucherDraft.fromVoucher(row);
      final body = VoucherModel.body(draft);
      expect(DateTime.parse(body['startDate'] as String), row.startsAt);
      expect(DateTime.parse(body['endDate'] as String), row.endsAt);
      expect(body['discountValue'], '12.50');
      expect(body['maxDiscountAmount'], '50000.25');
      expect(voucherVenueDay(row.startsAt), DateTime(2099, 11, 5));
      expect(
        voucherVenueDay(row.endsAt.subtract(const Duration(microseconds: 1))),
        DateTime(2099, 11, 10),
      );
    },
  );
}
