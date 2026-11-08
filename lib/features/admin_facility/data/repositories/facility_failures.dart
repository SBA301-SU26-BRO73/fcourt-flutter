import '../../../../core/error/failure.dart';
import '../../../../core/error/remote_call.dart';
import '../../domain/entities/court_lock.dart';

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
    409 when detail.startsWith('The window overlaps') => 'Khung giờ trùng với một lịch khóa đang có trên sân, hãy hủy lịch đó trước',
    409 when detail.startsWith('Slot overlaps') =>
      'Khung giờ trùng với mẫu khung giờ đang có',
    409 when detail.startsWith('Time range overlaps pricing rule') =>
      'Khung giờ trùng với một quy tắc giá khác trong cùng nhóm ngày',
    409 when detail.startsWith('Template cannot be applied') =>
      'Có sân không áp dụng được mẫu (${_conflictCount(detail) ?? 'một số'} '
          'sân); không có thay đổi nào được lưu. Hãy xem trước lại',
    409 => 'Dữ liệu bị trùng với bản ghi đã có',
    503 when detail.startsWith('Cannot verify') => 'Chưa kiểm tra được các lượt đặt/giữ chỗ hiện có nên chưa khóa. Vui lòng thử lại sau',
    503 => 'Dịch vụ gói tạm thời không phản hồi, vui lòng thử lại sau',
    400 when detail.startsWith('Court name already exists') =>
      'Tên sân đã tồn tại trong chi nhánh',
    400 when detail.startsWith('Slots must be within branch hours') =>
      'Khung giờ phải nằm trong giờ mở cửa của chi nhánh'
          '${_tail(detail, 'Slots must be within branch hours')}',
    400 when detail.startsWith('startAt and endAt must be') =>
      'Giờ bắt đầu và kết thúc phải là bội số của 30 phút',
    400 when detail.startsWith('endAt must be after') =>
      'Giờ kết thúc phải sau giờ bắt đầu',
    400 when detail.startsWith('The lock window is already in the past') =>
      'Khung giờ khóa đã qua, hãy chọn thời điểm trong tương lai',
    400 when detail.startsWith('A lock window can span') =>
      'Mỗi lịch khóa tối đa 31 ngày',
    400 when detail.startsWith('The branch has no courts') =>
      'Chi nhánh chưa có sân nào để khóa',
    400 when detail == 'endTime must be after startTime' =>
      'Giờ kết thúc phải sau giờ bắt đầu',
    400 when detail.startsWith('Times must be aligned') =>
      'Giờ bắt đầu và kết thúc phải là bội số của 30 phút',
    400 when detail.startsWith('There are no weekday pricing rules') =>
      'Chưa có quy tắc giá ngày thường để sao chép',
    400 when failure.errors.isNotEmpty =>
      'Dữ liệu chưa hợp lệ: ${failure.errors.join('; ')}',
    400 => 'Dữ liệu chưa hợp lệ: $detail',
    _ => detail,
  };
  return ServerFailure(
    message,
    statusCode: status,
    fieldErrors: failure.fieldErrors,
    errorLines: failure.errorLines,
  );
}

String _tail(String detail, String prefix) {
  final rest = detail.substring(prefix.length).trim();
  return rest.isEmpty ? '' : ' ($rest)';
}

/// [remoteCall] kèm thông báo lỗi tiếng Việt của facility-service.
Future<T> facilityCall<T>(Future<T> Function() call) =>
    remoteCall(call, localize: facilityFailure);

String? _conflictCount(String detail) =>
    RegExp(r'to (\d+) court').firstMatch(detail)?.group(1);

/// 409 `BOOKING_CONFLICT`: khóa bị từ chối vì có slot đã đặt hoặc đang giữ chỗ.
/// Không có gì được tạo ở server; [conflicts] để chủ sân biết cần liên hệ ai.
class LockConflictFailure extends ServerFailure {
  const LockConflictFailure(super.message, {required this.conflicts})
    : super(statusCode: 409);

  factory LockConflictFailure.fromConflicts(List<LockConflict> conflicts) {
    final booked = conflicts.where((c) => c.isBooked).length;
    final held = conflicts.length - booked;
    return LockConflictFailure(
      'Không thể khóa: có $booked slot đã được đặt và $held slot đang được '
      'giữ chỗ trong khung giờ này. Hãy liên hệ khách hoặc chọn khung giờ '
      'khác; chưa có gì bị khóa.',
      conflicts: conflicts,
    );
  }

  final List<LockConflict> conflicts;

  @override
  List<Object?> get props => [...super.props, conflicts];
}
