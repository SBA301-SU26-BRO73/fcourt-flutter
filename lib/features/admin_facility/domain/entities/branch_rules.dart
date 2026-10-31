import 'clock_time.dart';

/// Quy tắc kiểm tra dữ liệu chi nhánh/sân, trùng với validation của
/// facility-service (BranchRequest, CourtRequest). Mỗi hàm trả về thông báo
/// lỗi hoặc `null` nếu hợp lệ.
class BranchRules {
  const BranchRules._();

  // Độ dài tối đa theo @Size của BranchRequest / CourtRequest.
  static const maxName = 150;
  static const maxAddress = 255;
  static const maxWardOrDistrict = 100;
  static const maxAccountName = 150;
  static const maxCourtDescription = 2000;

  static final _bin = RegExp(r'^\d{6}$');
  static final _account = RegExp(r'^\d{6,20}$');
  // Giống BranchRequest.phone: `^\+?[0-9]{8,15}$`.
  static final _phone = RegExp(r'^\+?\d{8,15}$');

  static String? required(String? value, String label, {int? max}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Vui lòng nhập $label';
    return optional(value, label, max: max);
  }

  static String? optional(String? value, String label, {int? max}) {
    final length = value?.trim().length ?? 0;
    if (max == null || length <= max) return null;
    final title = label.isEmpty
        ? label
        : '${label[0].toUpperCase()}${label.substring(1)}';
    return '$title tối đa $max ký tự';
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return _phone.hasMatch(value.trim())
        ? null
        : 'Số điện thoại gồm 8–15 chữ số (có thể bắt đầu bằng +)';
  }

  static String? timeRange(ClockTime? open, ClockTime? close) {
    if (open == null || close == null) {
      return 'Vui lòng chọn giờ mở và đóng cửa';
    }
    if (!open.isBefore(close)) return 'Giờ đóng cửa phải sau giờ mở cửa';
    return null;
  }

  static String? bankBin(String? value) =>
      value != null && _bin.hasMatch(value) ? null : 'Vui lòng chọn ngân hàng';

  static String? accountNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Vui lòng nhập số tài khoản';
    return _account.hasMatch(text)
        ? null
        : 'Số tài khoản gồm 6–20 chữ số, không có ký tự khác';
  }

  static String? accountName(String? value) =>
      required(value, 'tên chủ tài khoản', max: maxAccountName);
}
