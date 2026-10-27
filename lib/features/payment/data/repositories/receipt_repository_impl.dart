import 'package:dio/dio.dart';

import '../../domain/entities/payment_checkout.dart';
import '../../domain/entities/payment_receipt.dart';
import '../../domain/repositories/receipt_repository.dart';

class ReceiptRepositoryImpl implements ReceiptRepository {
  const ReceiptRepositoryImpl(this.dio);
  final Dio dio;
  @override
  ReceiptSession open(CheckoutArguments arguments) => _Session(dio, arguments);
}

class _Session implements ReceiptSession {
  _Session(this.dio, this.arguments);
  final Dio dio;
  final CheckoutArguments arguments;
  final CancelToken _cancel = CancelToken();
  Options get options => Options(
    headers: {
      if (arguments.holdToken != null) 'X-Hold-Token': arguments.holdToken,
    },
  );
  @override
  void close() => _cancel.cancel('Payment session closed');

  @override
  Future<PaymentReceipt?> status() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/payments/${arguments.bookingId}/status',
        options: options,
        cancelToken: _cancel,
      );
      return parseReceipt(response.data, arguments.bookingId);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw receiptFailure(e);
    } on FormatException {
      throw const PaymentFailure('Trạng thái thanh toán không hợp lệ');
    }
  }

  @override
  Future<PaymentReceipt> upload(
    ReceiptImage image,
    void Function(double) onProgress,
  ) async {
    if (image.bytes.isEmpty || image.bytes.length > 5 * 1024 * 1024) {
      throw const PaymentFailure('Ảnh biên lai phải nhỏ hơn 5MB');
    }
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/api/payments/${arguments.bookingId}/upload-receipt',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(
            image.bytes,
            filename: 'receipt.jpg',
            contentType: DioMediaType('image', 'jpeg'),
          ),
        }),
        options: options,
        cancelToken: _cancel,
        onSendProgress: (sent, total) {
          if (total > 0) onProgress(sent / total);
        },
      );
      return parseReceipt(response.data, arguments.bookingId);
    } on DioException catch (e) {
      throw receiptFailure(e);
    } on FormatException {
      throw const PaymentFailure('Phản hồi tải biên lai không hợp lệ');
    }
  }
}

PaymentReceipt parseReceipt(Map<String, dynamic>? json, int bookingId) {
  if (json == null ||
      (json['rejectionReason'] != null && json['rejectionReason'] is! String) ||
      json['bookingId'] != bookingId ||
      json['id'] is! int ||
      (json['id'] as int) <= 0) {
    throw const FormatException('Invalid receipt');
  }
  final status = switch (json['status']) {
    'PENDING' => ReceiptStatus.pending,
    'CONFIRMED' => ReceiptStatus.confirmed,
    'REJECTED' => ReceiptStatus.rejected,
    'CANCELLED' => ReceiptStatus.cancelled,
    _ => throw const FormatException('Invalid status'),
  };
  return PaymentReceipt(
    id: json['id'] as int,
    bookingId: bookingId,
    status: status,
    rejectionReason: json['rejectionReason'] as String?,
  );
}

PaymentFailure receiptFailure(DioException e) =>
    switch (e.response?.statusCode) {
      400 || 413 => const PaymentFailure('Ảnh không hợp lệ hoặc vượt quá 5MB'),
      401 ||
      403 => const PaymentFailure('Bạn không có quyền truy cập thanh toán này'),
      410 => const PaymentFailure('Phiên giữ chỗ đã hết hạn', expired: true),
      409 => const PaymentFailure(
        'Trạng thái đơn đã thay đổi. Vui lòng tải lại.',
      ),
      _ => const PaymentFailure('Chưa kết nối được máy chủ. Vui lòng thử lại.'),
    };
