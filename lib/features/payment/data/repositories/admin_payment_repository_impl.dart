import 'package:dio/dio.dart';

import '../../domain/entities/payment_checkout.dart';
import '../../domain/entities/pending_payment.dart';
import '../../domain/repositories/admin_payment_repository.dart';

class AdminPaymentRepositoryImpl implements AdminPaymentRepository {
  const AdminPaymentRepositoryImpl(this.dio);
  final Dio dio;
  @override
  Future<List<PendingPayment>> pending(int branchId, {int offset = 0}) async {
    if (branchId <= 0 || offset < 0) {
      throw const PaymentFailure('Chi nhánh không hợp lệ');
    }
    try {
      final response = await dio.get<List<dynamic>>(
        '/api/admin/payments/pending',
        queryParameters: {'branchId': branchId, 'offset': offset},
      );
      final list = response.data;
      if (list == null) throw const FormatException('Missing payments');
      return list.map((item) => _parse(item, branchId)).toList();
    } on DioException catch (e) {
      throw _failure(e);
    } on FormatException {
      throw const PaymentFailure('Danh sách biên lai không hợp lệ');
    }
  }

  PendingPayment _parse(dynamic item, int branchId) {
    if (item is! Map<String, dynamic> ||
        item['branchId'] != branchId ||
        item['status'] != 'PENDING' ||
        item['id'] is! int ||
        item['bookingId'] is! int ||
        (item['id'] as int) <= 0 ||
        (item['bookingId'] as int) <= 0 ||
        item['checkout'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid payment');
    }
    final checkout = item['checkout'] as Map<String, dynamic>;
    final code = checkout['bookingCode'];
    final name = checkout['customerName'];
    final amount = item['amount'];
    final submitted = DateTime.tryParse(item['submittedAt']?.toString() ?? '');
    final url = Uri.tryParse(item['receiptImageUrl']?.toString() ?? '');
    if (code is! String ||
        code.isEmpty ||
        amount is! num ||
        !amount.isFinite ||
        amount <= 0 ||
        amount != amount.roundToDouble() ||
        submitted == null ||
        url == null ||
        url.scheme != 'https' ||
        url.host != 'res.cloudinary.com' ||
        url.userInfo.isNotEmpty ||
        (name != null && name is! String)) {
      throw const FormatException('Invalid receipt data');
    }
    return PendingPayment(
      id: item['id'] as int,
      bookingId: item['bookingId'] as int,
      bookingCode: code,
      customerName: name is String && name.isNotEmpty ? name : 'Khách đặt sân',
      amountVnd: amount.toInt(),
      receiptUri: url,
      submittedAt: submitted.toLocal(),
    );
  }

  @override
  Future<void> confirm(int paymentId) => _decide(paymentId, true);
  @override
  Future<void> reject(int paymentId, String reason) async {
    if (reason.trim().isEmpty || reason.trim().length > 500) {
      throw const PaymentFailure('Nhập lý do từ chối (tối đa 500 ký tự)');
    }
    await _decide(paymentId, false, reason.trim());
  }

  Future<void> _decide(int id, bool confirm, [String? reason]) async {
    try {
      final response = await dio.put<Map<String, dynamic>>(
        '/api/admin/payments/$id/${confirm ? 'confirm' : 'reject'}',
        data: confirm ? null : {'reason': reason},
      );
      final body = response.data;
      if (body == null ||
          body['id'] != id ||
          body['status'] != (confirm ? 'CONFIRMED' : 'REJECTED')) {
        throw const FormatException('Unexpected decision response');
      }
    } on DioException catch (e) {
      throw _failure(e);
    } on FormatException {
      throw const PaymentFailure(
        'Chưa xác minh được kết quả. Vui lòng tải lại danh sách.',
      );
    }
  }

  PaymentFailure _failure(DioException e) =>
      PaymentFailure(switch (e.response?.statusCode) {
        401 || 403 => 'Bạn không có quyền duyệt thanh toán của chi nhánh này',
        409 => 'Biên lai đã được xử lý. Vui lòng tải lại danh sách.',
        400 => 'Thông tin duyệt chưa hợp lệ',
        _ => 'Chưa kết nối được máy chủ. Vui lòng thử lại.',
      });
}
