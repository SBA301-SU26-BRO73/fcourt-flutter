/// BE trả lỗi bằng tiếng Anh; đổi sang tiếng Việt cho các lỗi đã biết, còn lại giữ nguyên.
class CatalogMessages {
  const CatalogMessages._();

  static const _vietnamese = {
    'Court type name already exists': 'Tên loại sân đã tồn tại',
    'Subscription plan name already exists': 'Tên gói dịch vụ đã tồn tại',
    'Court type not found': 'Loại sân không còn tồn tại, hãy tải lại danh sách',
    'Subscription plan not found': 'Gói dịch vụ không còn tồn tại, hãy tải lại danh sách',
    'You are not allowed to perform this action': 'Bạn không có quyền thực hiện thao tác này',
    'Authentication is required': 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại',
    'Invalid request fields': 'Dữ liệu chưa hợp lệ, vui lòng kiểm tra lại các ô bên dưới',
  };

  static String localize(String message) => _vietnamese[message] ?? message;

  static Map<String, String> localizeAll(Map<String, String> byField) =>
      byField.map((field, message) => MapEntry(field, localize(message)));
}
