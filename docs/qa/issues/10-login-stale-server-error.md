Title: [Android] Login giữ lỗi máy chủ cũ sau khi email không hợp lệ
Severity: low

Steps to reproduce:
1. Mở màn hình đăng nhập và nhập email/mật khẩu có vẻ hợp lệ, ví dụ `qa.user@example.com` / `Passw0rd!x`.
2. Nhấn `Đăng nhập` khi backend không chạy; đợi thông báo `Không kết nối được máy chủ`.
3. Thay email bằng `abc`, nhấn `Đăng nhập`. Lặp lại trong một lần tái hiện khác với `a@b`.

Expected: Khi form hiển thị lỗi xác thực email và không gửi request mới, thông báo lỗi máy chủ của lần gửi trước được xóa hoặc cập nhật để không mô tả sai trạng thái hiện tại.

Actual: Cả hai lần, `Email không hợp lệ` xuất hiện dưới trường email nhưng banner `Không kết nối được máy chủ` từ lần gửi trước vẫn ở đầu form.

Evidence: `qa/screens/58-login-stale-error-invalid.png` (`abc`) và `qa/screens/59-login-stale-error-invalid-repeat.png` (`a@b`). Tái hiện hai lần; không có logcat mới liên quan đến thao tác xác thực cục bộ.

Suspected area: `lib/features/auth/presentation/pages/login_page.dart` (banner lấy từ `LoginBloc` failure state; form không xóa trạng thái lỗi khi dữ liệu được sửa hoặc khi xác thực cục bộ thất bại).
