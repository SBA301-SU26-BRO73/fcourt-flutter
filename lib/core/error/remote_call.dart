import 'package:dio/dio.dart';

import 'failure.dart';

/// Chạy một lời gọi API và chuẩn hóa lỗi thành [Failure]:
/// - [DioException] → [failureFromDio] (401, ProblemDetail `detail`, mất mạng...).
/// - [FormatException] (JSON thiếu/sai trường) → [UnknownFailure] để không hiển
///   thị dữ liệu sai lệch.
Future<T> remoteCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw failureFromDio(e);
  } on FormatException {
    throw const UnknownFailure('Dữ liệu từ máy chủ không hợp lệ');
  }
}
