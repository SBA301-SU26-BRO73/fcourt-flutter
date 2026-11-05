import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/remote_call.dart';
import '../domain/voucher_usage.dart';
import '../domain/voucher_usage_repository.dart';

class VoucherUsageRepositoryImpl implements VoucherUsageRepository {
  const VoucherUsageRepositoryImpl(this.dio);
  final Dio dio;

  int _money(dynamic value) {
    if (value is! num ||
        !value.isFinite ||
        value < 0 ||
        value * 100 > 9007199254740991) {
      throw const FormatException();
    }
    final minor = value * 100;
    if ((minor - minor.round()).abs() > .001) throw const FormatException();
    return minor.round();
  }

  VoucherUsage _row(dynamic raw, int voucherId) {
    if (raw is! Map<String, dynamic>) throw const FormatException();
    int positive(String key) {
      final value = raw[key];
      if (value is! int || value <= 0) throw const FormatException();
      return value;
    }

    String? optional(String key, int max) {
      final value = raw[key];
      if (value == null) return null;
      if (value is! String || value.length > max) throw const FormatException();
      return value.trim().isEmpty ? null : value.trim();
    }

    final id = raw['id'], timestamp = raw['usedAt'];
    final time = timestamp is String ? DateTime.tryParse(timestamp) : null;
    final source = switch (raw['usedAtSource']) {
      'PAYMENT_CONFIRMED' => VoucherUsageTimeSource.paymentConfirmed,
      'RECORDED_AT' => VoucherUsageTimeSource.recordedAt,
      _ => null,
    };
    if (raw['voucherId'] != voucherId ||
        id is! String ||
        !RegExp(
          r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
        ).hasMatch(id) ||
        time == null ||
        !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(timestamp as String) ||
        source == null) {
      throw const FormatException();
    }
    return VoucherUsage(
      id: id,
      voucherId: voucherId,
      bookingId: positive('bookingId'),
      userId: positive('userId'),
      discountMinor: _money(raw['discountAmount']),
      usedAt: time.toUtc(),
      timeSource: source,
      customerName: optional('customerName', 100),
      customerPhone: optional('customerPhone', 100),
      bookingCode: optional('bookingCode', 50),
    );
  }

  @override
  Future<VoucherUsagePage> list(
    int voucherId, {
    int page = 0,
    String search = '',
  }) async {
    final phone = voucherPhoneDigits(search);
    if (voucherId <= 0 ||
        page < 0 ||
        page > 100000 ||
        search.length > 100 ||
        (search.trim().isNotEmpty && phone.isEmpty)) {
      throw const ServerFailure(
        'Vui lòng kiểm tra voucher, trang hoặc số điện thoại tìm kiếm',
      );
    }
    return remoteCall(
      () async {
        final raw = (await dio.get<Map<String, dynamic>>(
          '/api/admin/vouchers/$voucherId/usages',
          queryParameters: {
            'page': page,
            'size': VoucherUsagePage.size,
            if (phone.isNotEmpty) 'search': phone,
          },
        )).data;
        if (raw == null ||
            raw['page'] != page ||
            raw['size'] != VoucherUsagePage.size ||
            raw['total'] is! int ||
            raw['total'] < 0 ||
            raw['items'] is! List)
          throw const FormatException();
        final totalDiscount = _money(raw['totalDiscountAmount']);
        final items = (raw['items'] as List)
            .map((item) => _row(item, voucherId))
            .toList();
        if (items.length > VoucherUsagePage.size ||
            raw['total'] < items.length ||
            items.map((row) => row.id).toSet().length != items.length ||
            items.map((row) => row.bookingId).toSet().length != items.length ||
            items.fold<int>(0, (sum, row) => sum + row.discountMinor) >
                totalDiscount)
          throw const FormatException();
        if (phone.isNotEmpty &&
            items.any(
              (row) =>
                  row.customerPhone == null ||
                  !voucherPhoneDigits(row.customerPhone!).contains(phone),
            )) {
          throw const ServerFailure(
            'Máy chủ chưa trả kết quả lọc SĐT hợp lệ. Vui lòng cập nhật API lịch sử voucher.',
          );
        }
        return VoucherUsagePage(
          List.unmodifiable(items),
          page,
          raw['total'] as int,
          totalDiscount,
        );
      },
      localize: (failure) => ServerFailure(switch (failure.statusCode) {
        403 => 'Bạn không có quyền xem lịch sử voucher này.',
        404 => 'Không tìm thấy voucher trong phạm vi quản lý.',
        _ => failure.message,
      }, statusCode: failure.statusCode),
    );
  }
}
