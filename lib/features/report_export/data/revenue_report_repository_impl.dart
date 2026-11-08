import 'dart:io';

import '../../../core/error/failure.dart';
import '../../../core/error/remote_call.dart';
import '../domain/report_export.dart';
import 'report_file_store.dart';
import 'revenue_report_remote_data_source.dart';

class RevenueReportRepositoryImpl implements RevenueReportRepository {
  RevenueReportRepositoryImpl(
    this._remote,
    this._store, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final RevenueReportRemoteDataSource _remote;
  final ReportFileStore _store;
  final DateTime Function() _now;

  @override
  Future<DownloadedReport> download(
    RevenueReportRequest request, {
    void Function(double? fraction)? onProgress,
  }) async {
    final error = request.validationError;
    if (error != null) throw ServerFailure(error);
    final file = await remoteCall(
      () => _remote.download(request, onProgress: onProgress),
      localize: exportFailure,
    );
    if (file.bytes.isEmpty) {
      throw const UnknownFailure('Máy chủ trả về file rỗng');
    }
    final name = fileName(request, file.contentDisposition, _now());
    try {
      final path = await _store.save(name, file.bytes);
      return DownloadedReport(
        name: name,
        path: path,
        sizeBytes: file.bytes.length,
      );
    } on FileSystemException {
      throw const UnknownFailure('Không lưu được file vào thiết bị');
    }
  }

  /// Tên chuẩn hóa: `bao-cao-doanh-thu_<từ>_<đến>_xuat-<ngày xuất>.<đuôi>`.
  /// Phần đầu lấy từ `Content-Disposition` của backend (chỉ nhận ký tự an toàn);
  /// thiếu hoặc sai đuôi thì tự dựng từ khoảng ngày.
  static String fileName(
    RevenueReportRequest request,
    String? contentDisposition,
    DateTime exportedAt,
  ) {
    final ext = request.format.extension;
    String compact(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}';
    var base =
        'bao-cao-doanh-thu_${compact(request.from)}_${compact(request.to)}';
    final match = RegExp(
      r'filename="?([A-Za-z0-9._-]+)"?',
    ).firstMatch(contentDisposition ?? '');
    final suggested = match?.group(1);
    if (suggested != null &&
        suggested.endsWith('.$ext') &&
        suggested.length > ext.length + 1 &&
        !suggested.contains('..')) {
      base = suggested.substring(0, suggested.length - ext.length - 1);
    }
    return '${base}_xuat-${compact(exportedAt)}.$ext';
  }
}

/// reporting-service: 400 tham số sai, 403 chi nhánh của chủ khác, 503 facility lỗi.
Failure exportFailure(ServerFailure failure) {
  final message = switch (failure.statusCode) {
    400 => 'Yêu cầu xuất báo cáo không hợp lệ: ${failure.message}',
    403 => 'Bạn không có quyền xuất báo cáo của chi nhánh này',
    503 => 'Chưa lấy được thông tin chi nhánh, vui lòng thử lại sau',
    _ => failure.message,
  };
  return ServerFailure(message, statusCode: failure.statusCode);
}
