import 'voucher.dart';
import 'voucher_draft.dart';

class VoucherPage {
  const VoucherPage(this.items, this.page, this.total);
  static const size = 20;
  final List<Voucher> items;
  final int page, total;
  bool get hasMore => (page + 1) * size < total;
}

abstract interface class VoucherRepository {
  Future<VoucherPage> list(int branchId, {int page = 0});
  Future<Voucher> get(int id, int branchId);
  Future<Voucher> save(VoucherDraft draft, {int? id, int usedCount = 0});
  Future<Voucher> setEnabled(int id, int branchId, bool enabled);
}
