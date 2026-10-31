import 'clock_time.dart';

/// Quy tắc kiểm tra dữ liệu chi nhánh, trùng với validation của facility-service
/// (BranchRequest). Mỗi hàm trả về thông báo lỗi hoặc `null` nếu hợp lệ.
class BranchRules {
  const BranchRules._();

  static final _bin = RegExp(r'^\d{6}$');
  static final _account = RegExp(r'^\d{6,20}$');
  static final _phone = RegExp(r'^(\+84|0)\d{9,10}$');

  static String? required(String? value, String label) =>
      value == null || value.trim().isEmpty ? 'Vui lòng nhập $label' : null;

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return _phone.hasMatch(value.trim()) ? null : 'Số điện thoại không hợp lệ';
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

  static String? accountName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Vui lòng nhập tên chủ tài khoản';
    return text.length > 100 ? 'Tên chủ tài khoản tối đa 100 ký tự' : null;
  }
}
