import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../domain/report_export.dart';

class ReportBytes {
  const ReportBytes(this.bytes, this.contentDisposition);

  final Uint8List bytes;
  final String? contentDisposition;
}

/// Gọi `GET /api/admin/dashboard/export/revenue` của reporting-service.
class RevenueReportRemoteDataSource {
  const RevenueReportRemoteDataSource(this._dio);

  final Dio _dio;

  static const path = '/api/admin/dashboard/export/revenue';

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<ReportBytes> download(
    RevenueReportRequest request, {
    void Function(double? fraction)? onProgress,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        queryParameters: {
          'fromDate': _date(request.from),
          'toDate': _date(request.to),
          'format': request.format.extension,
          'branchId': ?request.branchId,
        },
        // Dio mặc định gửi Accept: application/json; đây là file nhị phân.
        options: Options(
          responseType: ResponseType.bytes,
          headers: const {'Accept': '*/*'},
        ),
        onReceiveProgress: (received, total) =>
            onProgress?.call(total > 0 ? received / total : null),
      );
      final data = response.data;
      if (data == null) throw const FormatException('Thiếu nội dung file');
      return ReportBytes(
        Uint8List.fromList(data),
        response.headers.value('content-disposition'),
      );
    } on DioException catch (e) {
      // Lỗi trả về JSON ProblemDetail nhưng được đọc dạng bytes: giải mã để
      // failureFromDio lấy được `detail`.
      final body = e.response?.data;
      if (body is List<int>) {
        try {
          e.response!.data = jsonDecode(utf8.decode(body));
        } on FormatException {
          e.response!.data = null;
        }
      }
      rethrow;
    }
  }
}
