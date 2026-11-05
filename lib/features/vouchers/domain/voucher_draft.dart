import 'voucher.dart';

class VoucherDraft {
  const VoucherDraft({
    required this.branchId,
    required this.code,
    required this.type,
    required this.value,
    this.cap = '',
    this.minimum = '',
    required this.limit,
    required this.startsAt,
    required this.endsAt,
    this.status = VoucherStatus.active,
  });
  final int branchId;
  final String code, value, cap, minimum, limit;
  final VoucherDiscountType type;
  final DateTime startsAt, endsAt;
  final VoucherStatus status;

  factory VoucherDraft.fromVoucher(Voucher row, {VoucherStatus? status}) =>
      VoucherDraft(
        branchId: row.branchId,
        code: row.code,
        type: row.type,
        value: voucherDecimal(row.valueMinor),
        cap: row.capMinor == null ? '' : voucherDecimal(row.capMinor!),
        minimum: voucherDecimal(row.minOrderMinor),
        limit: '${row.limit}',
        startsAt: row.startsAt,
        endsAt: row.endsAt,
        status: status ?? row.status,
      );

  Map<String, String> errors({int usedCount = 0}) {
    final result = <String, String>{};
    if (branchId <= 0) result['branchId'] = 'Vui lòng chọn chi nhánh';
    if (!RegExp(r'^[A-Z0-9_-]{1,50}$').hasMatch(code.trim().toUpperCase())) {
      result['code'] = 'Mã gồm 1–50 ký tự A–Z, 0–9, _ hoặc -';
    }
    final decimal = RegExp(r'^\d{1,10}(\.\d{1,2})?$');
    for (final entry in {
      'discountValue': value,
      'maxDiscountAmount': cap,
      'minOrderAmount': minimum,
    }.entries) {
      if (entry.value.trim().isEmpty && entry.key != 'discountValue') continue;
      if (!decimal.hasMatch(entry.value.trim())) {
        result[entry.key] =
            'Nhập số không âm, tối đa 10 chữ số và 2 số thập phân';
      }
    }
    final amount = double.tryParse(value.trim());
    if (!result.containsKey('discountValue') &&
        (amount == null ||
            amount <= 0 ||
            (type == VoucherDiscountType.percentage && amount > 100))) {
      result['discountValue'] = type == VoucherDiscountType.percentage
          ? 'Phần trăm phải lớn hơn 0 và không quá 100'
          : 'Số tiền giảm phải lớn hơn 0';
    }
    if (cap.trim().isNotEmpty &&
        !result.containsKey('maxDiscountAmount') &&
        double.parse(cap.trim()) <= 0) {
      result['maxDiscountAmount'] = 'Mức giảm tối đa phải lớn hơn 0';
    }
    final count = int.tryParse(limit.trim());
    if (!RegExp(r'^\d+$').hasMatch(limit.trim()) ||
        count == null ||
        count < 1 ||
        count > 2147483647 ||
        count < usedCount) {
      result['usageLimit'] =
          'Số lượt phải từ ${usedCount > 1 ? usedCount : 1} đến 2147483647';
    }
    if (!startsAt.isBefore(endsAt)) {
      result['dates'] = 'Ngày bắt đầu phải trước thời điểm kết thúc';
    }
    return result;
  }
}
