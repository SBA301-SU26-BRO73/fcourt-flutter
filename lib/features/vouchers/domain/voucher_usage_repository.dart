import 'voucher_usage.dart';

abstract interface class VoucherUsageRepository {
  Future<VoucherUsagePage> list(int voucherId, {int page = 0, String search = ''});
}
