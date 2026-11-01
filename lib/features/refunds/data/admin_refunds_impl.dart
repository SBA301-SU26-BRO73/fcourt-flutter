import 'package:dio/dio.dart';

import '../domain/admin_refunds.dart';
import '../domain/refund.dart';
import '../../payment/domain/entities/payment_receipt.dart';
import '../../../core/error/failure.dart';
import 'refund_repository_impl.dart';

class AdminRefundsImpl implements AdminRefunds {
  const AdminRefundsImpl(this.dio);
  final Dio dio;
  @override
  Future<List<RefundRequest>> pending(int branchId, {int page = 0}) async {
    try {
      final raw = (await dio.get<List<dynamic>>(
        '/api/admin/refunds/pending',
        queryParameters: {'branchId': branchId, 'page': page, 'size': 20},
      )).data;
      if (raw == null || raw.length > 20) throw const FormatException();
      final rows = raw.map(RefundRepositoryImpl.parse).toList();
      if (rows.map((r) => r.id).toSet().length != rows.length ||
          rows.any((r) => !{'PENDING', 'APPROVED'}.contains(r.status))) {
        throw const FormatException();
      }
      return rows;
    } on DioException catch (e) {
      throw RefundRepositoryImpl.failure(e);
    } on FormatException {
      throw const ServerFailure('Danh sách hoàn tiền không hợp lệ');
    }
  }

  Future<RefundRequest> _decide(
    int id,
    String action,
    Object? data,
    String expected,
  ) async {
    try {
      final r = RefundRepositoryImpl.parse(
        (await dio.put<Map<String, dynamic>>(
          '/api/admin/refunds/$id/$action',
          data: data,
        )).data,
      );
      if (r.id != id || r.status != expected) throw const FormatException();
      return r;
    } on DioException catch (e) {
      throw RefundRepositoryImpl.failure(e);
    } on FormatException {
      throw const ServerFailure(
        'Chưa xác nhận được kết quả. Vui lòng tải lại.',
      );
    }
  }

  @override
  Future<RefundRequest> approve(int id) =>
      _decide(id, 'approve', null, 'APPROVED');
  @override
  Future<RefundRequest> reject(int id, String reason) =>
      _decide(id, 'reject', {'reason': reason.trim()}, 'REJECTED');
  @override
  Future<RefundRequest> complete(int id, ReceiptImage proof) {
    if (proof.bytes.isEmpty || proof.bytes.length > 5 * 1024 * 1024) {
      throw const ServerFailure('Chứng từ phải nhỏ hơn 5MB');
    }
    return _decide(
      id,
      'complete',
      FormData.fromMap({
        'file': MultipartFile.fromBytes(
          proof.bytes,
          filename: 'refund-proof.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        ),
      }),
      'COMPLETED',
    );
  }
}
