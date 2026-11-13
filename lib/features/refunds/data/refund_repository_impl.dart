import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../domain/refund.dart';
import '../../../core/network/image_url.dart';

class RefundRepositoryImpl implements RefundRepository {
  const RefundRepositoryImpl(this.dio);
  final Dio dio;
  @override
  Future<RefundState> load(int bookingId) async {
    try {
      final r = (await dio.get<Map<String, dynamic>>(
        '/api/refunds/booking/$bookingId',
      )).data;
      if (r == null || r['bookingId'] != bookingId || r['eligible'] is! bool) {
        throw const FormatException();
      }
      final amount = money(r['amount']);
      final request = r['request'] == null ? null : parse(r['request']);
      if (request != null &&
          (request.bookingId != bookingId || request.amount != amount)) {
        throw const FormatException();
      }
      return RefundState(bookingId, amount, r['eligible'] as bool, request);
    } on DioException catch (e) {
      throw failure(e);
    } on FormatException {
      throw const ServerFailure('Dữ liệu hoàn tiền không hợp lệ');
    }
  }

  @override
  Future<RefundRequest> request(int bookingId, RefundBankDetails d) async {
    try {
      final r = (await dio.post<Map<String, dynamic>>(
        '/api/refunds/request',
        data: {
          'bookingId': bookingId,
          'bankName': d.bankName,
          'bankBin': d.bankBin,
          'bankAccountNumber': d.accountNumber.trim(),
          'bankAccountName': d.accountName.trim(),
          'reason': d.reason.trim(),
        },
      )).data;
      final result = parse(r);
      if (result.bookingId != bookingId) throw const FormatException();
      return result;
    } on DioException catch (e) {
      throw failure(e);
    } on FormatException {
      throw const ServerFailure(
        'Chưa xác nhận được yêu cầu. Vui lòng tải lại trạng thái.',
      );
    }
  }

  static int money(dynamic v) {
    if (v is! num || !v.isFinite || v <= 0 || v != v.roundToDouble()) {
      throw const FormatException();
    }
    return v.toInt();
  }

  static RefundRequest parse(dynamic r, {bool adminList = false}) {
    if (r is! Map ||
        r['id'] is! int ||
        r['id'] <= 0 ||
        r['bookingId'] is! int ||
        r['bookingId'] <= 0) {
      throw const FormatException();
    }
    String text(String k) {
      final v = r[k];
      if (v is! String || v.isEmpty || v.length > 1000) {
        throw const FormatException();
      }
      return v;
    }

    final bankMissing = adminList && r['bankInfoMissing'] == true;
    final bankName = bankMissing ? '' : text('bankName');
    final bankBin = bankMissing ? '' : text('bankBin');
    final accountNumber = bankMissing ? '' : text('bankAccountNumber');
    final accountName = bankMissing ? '' : text('bankAccountName');
    if (!bankMissing &&
        (!RegExp(r'^970[0-9]{3}$').hasMatch(bankBin) ||
            !RegExp(r'^[0-9]{6,20}$').hasMatch(accountNumber))) {
      throw const FormatException();
    }
    final status = text('status');
    if (!{'PENDING', 'APPROVED', 'REJECTED', 'COMPLETED'}.contains(status)) {
      throw const FormatException();
    }
    final created = DateTime.tryParse(text('createdAt')),
        updated = DateTime.tryParse(text('updatedAt'));
    if (created == null || updated == null) throw const FormatException();
    final note = r['adminNote'];
    if (note != null && note is! String) throw const FormatException();
    Uri? proof;
    if (r['transferProofUrl'] != null) {
      if (r['transferProofUrl'] is! String) throw const FormatException();
      proof = Uri.tryParse(r['transferProofUrl'] as String);
      if (!isAllowedImageUrl(proof)) {
        throw const FormatException();
      }
    }
    return RefundRequest(
      id: r['id'] as int,
      bookingId: r['bookingId'] as int,
      amount: money(r['amount']),
      status: status,
      bankName: bankName,
      bankBin: bankBin,
      accountNumber: accountNumber,
      accountName: accountName,
      reason: text('reason'),
      createdAt: created,
      updatedAt: updated,
      note: note as String?,
      proof: proof,
    );
  }

  static Failure failure(DioException e) => switch (e.response?.statusCode) {
    409 => const ServerFailure(
      'Đơn chưa đủ điều kiện hoặc đã có yêu cầu hoàn tiền. Hãy tải lại trạng thái.',
    ),
    503 => const ServerFailure(
      'Chưa xác minh được chính sách hoàn tiền. Vui lòng thử lại.',
    ),
    _ => failureFromDio(e),
  };
}
