/// BE trả lỗi bằng tiếng Anh; đổi sang tiếng Việt cho các lỗi đã biết, còn lại giữ nguyên.
class AuthMessages {
  const AuthMessages._();

  static const _vietnamese = {
    'Invalid email or password': 'Email hoặc mật khẩu không đúng',
    'Account is awaiting approval': 'Tài khoản đang chờ quản trị viên duyệt',
    'Account registration was rejected': 'Hồ sơ đăng ký đã bị từ chối',
    'Account is locked': 'Tài khoản đã bị khóa',
    'Account is inactive': 'Tài khoản không còn hoạt động',
    'Email is already registered': 'Email này đã được đăng ký',
    'Phone number is already registered': 'Số điện thoại này đã được đăng ký',
    'Email or phone number is already registered':
        'Email hoặc số điện thoại đã được đăng ký',
    'Document storage is unavailable':
        'Hệ thống lưu tài liệu đang bận, vui lòng thử lại sau',
    'legalDocuments is required': 'Vui lòng chọn ít nhất 1 giấy tờ pháp lý',
    'legalDocuments accepts only JPEG, PNG, WebP or PDF files':
        'Giấy tờ chỉ nhận ảnh JPEG, PNG, WebP hoặc PDF',
    'courtImages accepts only JPEG, PNG, WebP or PDF files':
        'Ảnh sân chỉ nhận JPEG, PNG, WebP hoặc PDF',
    'legalDocuments files must be at most 5 MB': 'Mỗi tệp tối đa 5 MB',
    'courtImages files must be at most 5 MB': 'Mỗi tệp tối đa 5 MB',
    'legalDocuments accepts at most 5 files': 'Tối đa 5 giấy tờ pháp lý',
    'courtImages accepts at most 10 files': 'Tối đa 10 ảnh sân',
    'Account not found': 'Không tìm thấy tài khoản',
  };

  static String localize(String message) => _vietnamese[message] ?? message;

  static Map<String, String> localizeAll(Map<String, String> byField) =>
      byField.map((field, message) => MapEntry(field, localize(message)));
}
