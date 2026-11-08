# Báo cáo QA thủ công – FCOURT Android (entry/auth)

Ngày chạy: 2026-11-09. Thiết bị: Pixel 8 emulator, Android 15, 1080×2400, `emulator-5554`. App: `com.bro73.fcourt`. Backend không chạy (`http://10.0.2.2:8080` không có dịch vụ). Không có lỗi đủ điều kiện lập issue: không có defect nào được xác nhận hai lần.

Đã đọc source: `lib/app/router.dart`, `lib/features/auth/presentation/pages/login_page.dart`, `forgot_password_page.dart`, `register_customer_page.dart`, `register_owner_page.dart`, và `lib/features/auth/presentation/validators.dart`. Router có các màn public auth (login, đăng ký khách/chủ sân, quên/đặt lại mật khẩu) và health check; các đường dẫn còn lại là màn yêu cầu phiên đăng nhập/role hoặc dữ liệu phụ thuộc phiên. Không thấy đường UI từ entry đến health check hay reset token.

| Scenario | Kết quả | Ghi nhận |
|---|---|---|
| Login – gửi trống | pass | Hiện lỗi email và mật khẩu tại form. Ảnh: `(ảnh lưu cục bộ, không commit) screens/02-login-empty-validation.png`. |
| Login – email sai định dạng | not reachable | Thao tác nhập liệu qua ADB bị dồn ký tự vào cùng một trường; chưa xác nhận chính xác hành vi. |
| Login – email/mật khẩu rất dài | not reachable | Chưa chạy được thao tác nhập đáng tin cậy. |
| Login – bật/tắt hiện mật khẩu | not reachable | Widget có nút toggle theo UI tree nhưng chưa xác minh hành vi trên giá trị nhập được. |
| Login – bàn phím che trường/nút; nhấn ENTER | not reachable | Chưa xác minh do focus/nhập liệu không ổn định trong thao tác ADB. |
| Login – nhấn Đăng nhập hai lần nhanh | not reachable | Chưa chạy với form hợp lệ. |
| Login – backend không phản hồi | not reachable | Không gửi được request login hợp lệ; không kết luận về thông báo/lỗi/spinner/crash. |
| Login – Google không có tài khoản | not reachable | Nút hiện thông báo tiếng Việt “Thiếu cấu hình Google Web Client ID”; không thể tới bước chọn tài khoản Google. Đây là cấu hình app trong build, không phải kết quả kiểm tra tài khoản. Ảnh: `(ảnh lưu cục bộ, không commit) screens/05-login-server-error.png`. |
| Login → Quên mật khẩu? | not reachable | Chưa xác nhận được trang qua thao tác UI lặp lại. |
| Login → Đăng ký khách hàng | not reachable | Chưa xác minh được trang bằng ảnh/UI tree đáng tin cậy; chưa gửi form. |
| Login → Đăng ký chủ sân | pass | Màn hình mở được. Có 5 trường, giấy tờ pháp lý bắt buộc, ảnh sân tùy chọn; nhấn Chọn giấy tờ mở Android Files. Ảnh: `(ảnh lưu cục bộ, không commit) screens/09-register-owner.png`, `(ảnh lưu cục bộ, không commit) screens/10-owner-picker.png`. |
| Đăng ký khách – required fields/password rules | not reachable | Chưa kiểm tra submit/validator trực tiếp trên thiết bị. Quy tắc được đọc trong source. |
| Đăng ký chủ sân – required fields/password rules | not reachable | Chưa kiểm tra đủ thao tác submit và nhập. Source yêu cầu giấy tờ pháp lý và dùng validators chung. |
| Đăng ký – BACK, state khi quay lại | not reachable | Chưa xác minh việc giữ/mất dữ liệu sau khi nhập form. |
| Forgot password – tới bước cần backend | not reachable | Chưa xác minh UI form trên thiết bị; yêu cầu gửi link cần backend đang vắng mặt. |
| Font scale 1.3 | pass | Login vẫn hiển thị các trường và CTA trong ảnh đã chụp. Ảnh: `(ảnh lưu cục bộ, không commit) screens/13-font-1-3.png`. |
| Font scale 1.5 | pass | Login vẫn hiển thị CTA và liên kết trong ảnh. Ảnh: `(ảnh lưu cục bộ, không commit) screens/14-font-1-5.png`. |
| Landscape | not reachable | Đã chụp màn login xoay ngang; phần thấp của nội dung bị ngoài viewport ban đầu. Chưa thử cuộn để xác minh nút có thể tiếp cận nên không kết luận là defect. Ảnh: `(ảnh lưu cục bộ, không commit) screens/16-landscape.png`. |
| Dark mode | pass | Màn login đổi sang nền tối; chữ và nút vẫn phân biệt được. Ảnh: `(ảnh lưu cục bộ, không commit) screens/15-dark.png`. |
| Bàn phím mở trên màn auth | not reachable | Có ảnh keyboard mở, nhưng nội dung trường lúc đó chứa chuỗi thử nghiệm sai do thao tác ADB; không dùng để kết luận layout. Ảnh: `(ảnh lưu cục bộ, không commit) screens/21-login-keyboard-open.png`. |
| Lifecycle – HOME rồi quay lại | not reachable | Thao tác HOME/return làm app về launcher; chưa xác nhận được trạng thái app sau khi mở lại. |
| Lifecycle – xoay khi field có nội dung | not reachable | Có thao tác xoay nhưng field không được điền đúng và app không ở màn mục tiêu; không kết luận. |
| Lifecycle – force-stop và relaunch | not reachable | App mở lại đến login sau khi đợi; chưa xác minh trường có lưu mật khẩu/giá trị dở dang. |
| Các màn không cần session khác theo router | not reachable | Không có liên kết UI public khác ngoài auth; health check và reset-password token không thể mở từ entry flow. Không deep-link hay điều hướng ngoài UI. |

## Issue files

Không có issue file. Không ghi lỗi chưa tái hiện hai lần.

## Chưa kiểm tra được

- Không có backend, nên không xác minh được response/error thật của login, đăng ký, forgot password hay các màn cần session.
- Build thiếu Google Web Client ID; Google account chooser không mở được.
- Nhập liệu/nhấn liên kết qua ADB không ổn định trong vài trường hợp, vì vậy các kết quả cần dữ liệu nhập không được suy diễn.
- Không mở được reset-password flow vì cần token; không có route public khác truy cập được từ màn hình UI.

## Cài đặt emulator

Giá trị ban đầu đã đọc: `font_scale=1.0`, `accelerometer_rotation=1`, `user_rotation=0`, night mode `no`. Đã đổi font scale lần lượt sang 1.3 và 1.5, bật dark mode, tắt auto-rotate và đặt user rotation 1 cho kiểm tra ngang. Đã khôi phục cuối lượt: `font_scale=1.0`, `accelerometer_rotation=1`, `user_rotation=0`, night mode `no` (đã đọc lại để xác nhận). Không đổi display size.

