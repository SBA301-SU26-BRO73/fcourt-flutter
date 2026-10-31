import '../../../../core/error/failure.dart';
import '../../../../core/error/remote_call.dart';

/// Đổi lỗi ProblemDetail (tiếng Anh) của facility-service sang thông báo tiếng
/// Việt; giữ mã trạng thái và `errors` để tầng trên vẫn phân biệt được.
///
/// - 404: facility trả 404 cả khi tài nguyên thuộc chủ sân khác (không 403).
/// - 403: vượt giới hạn gói hoặc chưa có gói (subscription-service).
/// - 400: lỗi từng trường được liệt kê sau thông báo chung.
Failure facilityFailure(ServerFailure failure) {
  final detail = failure.message;
  final status = failure.statusCode;
  final limit = RegExp(r'\((\d+)\)').firstMatch(detail)?.group(1);
  final suffix = limit == null ? '' : ' ($limit)';
  final message = switch (status) {
    404 =>
      'Không tìm thấy dữ liệu, hoặc chi nhánh/sân này không thuộc quyền '
          'quản lý của bạn',
    403 when detail.startsWith('Branch limit') =>
      'Đã đạt số chi nhánh tối đa của gói dịch vụ$suffix',
    403 when detail.startsWith('Court limit') =>
      'Đã đạt số sân tối đa của gói dịch vụ$suffix',
    403 when detail.startsWith('No active subscription') =>
      'Bạn chưa có gói dịch vụ đang hoạt động',
    403 => 'Bạn không có quyền thực hiện thao tác này',
    409 when detail.startsWith('Slot overlaps') =>
      'Khung giờ trùng với mẫu khung giờ đang có',
    409 => 'Dữ liệu bị trùng với bản ghi đã có',
    503 => 'Dịch vụ gói tạm thời không phản hồi, vui lòng thử lại sau',
    400 when detail.startsWith('Court name already exists') =>
      'Tên sân đã tồn tại trong chi nhánh',
    400 when detail.startsWith('Slots must be within branch hours') =>
      'Khung giờ phải nằm trong giờ mở cửa của chi nhánh'
          '${_tail(detail, 'Slots must be within branch hours')}',
    400 when failure.errors.isNotEmpty =>
      'Dữ liệu chưa hợp lệ: ${failure.errors.join('; ')}',
    400 => 'Dữ liệu chưa hợp lệ: $detail',
    _ => detail,
  };
  return ServerFailure(message, statusCode: status, errors: failure.errors);
}

String _tail(String detail, String prefix) {
  final rest = detail.substring(prefix.length).trim();
  return rest.isEmpty ? '' : ' ($rest)';
}

/// [remoteCall] kèm thông báo lỗi tiếng Việt của facility-service.
Future<T> facilityCall<T>(Future<T> Function() call) =>
    remoteCall(call, localize: facilityFailure);
