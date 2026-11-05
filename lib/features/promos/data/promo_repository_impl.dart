import 'package:dio/dio.dart';

import '../domain/booking_promo.dart';
import '../domain/promo_repository.dart';

class PromoRepositoryImpl implements PromoRepository {
  const PromoRepositoryImpl(this.api, this.vouchers);
  final Dio api, vouchers;

  int _money(dynamic value) {
    if (value is! num || !value.isFinite || value < 0 || value > 99999999.99) {
      throw const FormatException();
    }
    final minor = value * 100;
    if ((minor - minor.round()).abs() > .001) throw const FormatException();
    return minor.round();
  }

  DateTime _instant(dynamic raw) {
    if (raw is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw))
      throw const FormatException();
    return DateTime.tryParse(raw)?.toUtc() ?? (throw const FormatException());
  }

  bool _uuid(dynamic raw) =>
      raw is String &&
      RegExp(
        r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
      ).hasMatch(raw);
  PromoFailure _failure(DioException error) {
    final status = error.response?.statusCode;
    final raw = error.response?.data;
    final detail = raw is Map ? raw['detail'] ?? raw['message'] : null;
    return PromoFailure(
      switch (status) {
        401 || 403 =>
          'Vui lòng đăng nhập bằng tài khoản khách sở hữu đơn để dùng voucher.',
        404 => 'Chưa tìm thấy đơn hoặc chức năng voucher. Vui lòng thử lại.',
        410 => 'Đơn đặt sân đã hết thời gian giữ chỗ.',
        400 || 409 =>
          detail is String && detail.isNotEmpty && detail.length <= 1000
              ? detail
              : 'Mã voucher chưa phù hợp hoặc đơn đã khóa thanh toán.',
        _ => 'Chưa xác nhận được kết quả áp dụng. Vui lòng thử lại cùng mã hoặc tải lại thanh toán.',
      },
      expired: status == 410,
      uncertain: status == null || status >= 500,
    );
  }

  @override
  Future<BookingPromo> snapshot(int bookingId) async {
    if (bookingId <= 0) throw const PromoFailure('Mã đơn không hợp lệ');
    try {
      // Voucher eligibility always uses the customer JWT, never a guest hold token.
      final raw = (await api.get<Map<String, dynamic>>(
        '/api/bookings/$bookingId',
      )).data;
      if (raw == null ||
          raw['id'] != bookingId ||
          raw['status'] is! String ||
          (raw['paymentFrozen'] != null && raw['paymentFrozen'] is! bool))
        throw const FormatException();
      final finalMinor = _money(raw['totalPrice']);
      final original = _money(raw['originalAmount'] ?? raw['totalPrice']);
      final discount = _money(raw['discountAmount'] ?? 0);
      final id = raw['voucherApplicationId'];
      if (original <= 0 ||
          original - discount != finalMinor ||
          (id == null && (discount != 0 || finalMinor == 0)) ||
          (id != null &&
              (!_uuid(id) ||
                  raw['originalAmount'] == null ||
                  raw['discountAmount'] == null)))
        throw const FormatException();
      return BookingPromo(
        bookingId: bookingId,
        originalMinor: original,
        discountMinor: discount,
        finalMinor: finalMinor,
        applicationId: id as String?,
        status: raw['status'] as String,
        paymentFrozen: raw['paymentFrozen'] == true,
        expiresAt: _instant(raw['holdExpiresAt']),
      );
    } on DioException catch (error) {
      throw _failure(error);
    } on FormatException {
      throw const PromoFailure(
        'Dữ liệu khuyến mãi của đơn chưa hợp lệ. Vui lòng tải lại.',
      );
    }
  }

  @override
  Future<PromoApplication> apply(
    int bookingId,
    String code,
    int originalMinor,
  ) async {
    final normalized = code.trim().toUpperCase();
    if (bookingId <= 0 ||
        !RegExp(r'^[A-Z0-9_-]{1,50}$').hasMatch(normalized) ||
        originalMinor <= 0 ||
        originalMinor > 9999999999) {
      throw const PromoFailure('Mã gồm 1–50 ký tự A–Z, 0–9, _ hoặc -.');
    }
    try {
      final raw = (await vouchers.post<Map<String, dynamic>>(
        '/api/vouchers/apply',
        data: {
          'code': normalized,
          'bookingId': bookingId,
          'totalAmount': promoDecimal(originalMinor),
        },
      )).data;
      if (raw == null ||
          raw['bookingId'] != bookingId ||
          !_uuid(raw['applicationId']) ||
          raw['voucherId'] is! int ||
          raw['voucherId'] <= 0)
        throw const FormatException();
      final original = _money(raw['originalAmount']),
          discount = _money(raw['discountAmount']),
          finalMinor = _money(raw['finalAmount']);
      _instant(raw['expiresAt']);
      if (original != originalMinor || original - discount != finalMinor)
        throw const FormatException();
      return PromoApplication(
        bookingId: bookingId,
        applicationId: raw['applicationId'] as String,
        originalMinor: original,
        discountMinor: discount,
        finalMinor: finalMinor,
      );
    } on DioException catch (error) {
      throw _failure(error);
    } on FormatException {
      throw const PromoFailure(
        'Chưa đối soát được số tiền sau giảm. Hãy thử lại cùng mã.',
        uncertain: true,
      );
    }
  }

  @override
  Future<void> confirmFree(int bookingId) async {
    if (bookingId <= 0) throw const PromoFailure('Mã đơn không hợp lệ');
    try {
      final raw = (await api.post<Map<String, dynamic>>(
        '/api/payments/$bookingId/confirm-free',
      )).data;
      if (raw == null ||
          raw['bookingId'] != bookingId ||
          raw['status'] != 'CONFIRMED' ||
          raw['amount'] != 0)
        throw const FormatException();
    } on DioException catch (error) {
      throw _failure(error);
    } on FormatException {
      throw const PromoFailure(
        'Chưa xác nhận được đơn miễn phí. Vui lòng thử lại.',
        uncertain: true,
      );
    }
  }
}
