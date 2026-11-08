# Báo cáo QA thủ công – FCOURT Android (entry/auth), lượt 2

Ngày chạy: 2026-11-09. Thiết bị: Pixel 8 emulator, Android 15, `emulator-5554`, 1080×2400 portrait. App: `com.bro73.fcourt`. Backend không chạy; auth request tới `http://10.0.2.2:8080` bị từ chối kết nối.

| Scenario | Kết quả | Ghi nhận |
|---|---|---|
| 1. Login: email `abc`, `a@b`, `a b@c.vn` | pass / fail | Cả ba giá trị hiện `Email không hợp lệ`. Với `abc` và `a@b`, banner lỗi máy chủ từ lần gửi trước vẫn còn; lỗi UI này được tái hiện hai lần và ghi ở issue 10. |
| 1. Login: email và mật khẩu dài 200 ký tự | pass | Email dài bị báo `Email không hợp lệ`; mật khẩu dài được nhập và có thể gửi. Server không thể xác nhận quy tắc độ dài phía server. Không crash. |
| 1. Login: hiện/ẩn mật khẩu | pass | `Passw0rd!x` chuyển giữa text đọc được và dấu chấm; thuộc tính UI `password` đổi theo toggle. |
| 1. Login: ENTER ở trường mật khẩu | pass | ENTER gửi form; lỗi kết nối được hiển thị sau khoảng 2 giây. |
| 1. Login: chạm nút Đăng nhập hai lần nhanh | pass | Có một lần xử lý request (Logcat ghi request và một Dio error response); nút chuyển trạng thái gửi. Không thấy crash hoặc spinner vô hạn. Backend vắng mặt nên không thể xác minh side effect phía server. |
| 1. Login: server không tới được | pass | App giữ màn login, hiển thị thông báo tiếng Việt `Không kết nối được máy chủ` khoảng 2 giây sau thao tác. Sau khi đợi tới 30 giây, thông báo vẫn hiển thị, không có spinner vô hạn hay crash của app. Logcat có `Connection refused` tới `10.0.2.2:8080`. |
| 2. Login → Quên mật khẩu?; để trống, email sai, email hợp lệ | pass | Màn hình mở được. Submit trống hiện `Vui lòng nhập email`; `abc` hiện `Email không hợp lệ`. Submit `qa.reset@example.com` gửi request rồi hiện `Không kết nối được máy chủ` sau khoảng 2 giây; màn hình không chuyển sang trạng thái đã gửi link. |
| 3. Login → Đăng ký khách; trường bắt buộc, password, phone, submit hợp lệ | pass | Submit trống báo lỗi cho họ tên, email, điện thoại, mật khẩu và xác nhận. Mật khẩu ngắn báo tối thiểu 8 ký tự; xác nhận sai báo không khớp; phone `123` báo sai định dạng. `Abcdefgh` (không số) và `abcde123` (không chữ hoa) qua được kiểm tra cục bộ, request tiếp theo nhận `Không kết nối được máy chủ`. Source chỉ áp dụng độ dài 8–72 ký tự/byte, không đặt luật số/chữ hoa. |
| 4. Đăng ký chủ sân: submit trống, trường bắt buộc và giấy tờ | pass | Submit trống hiển thị lỗi họ tên, email, điện thoại, mật khẩu, xác nhận và yêu cầu giấy tờ pháp lý. Picker Android Files có các file ảnh mẫu; chọn `appendix-edit.png` trở lại form với tên file được hiển thị. Form hợp lệ với file đã chọn gửi request và hiện `Không kết nối được máy chủ`. |
| 5. BACK và trạng thái khi quay lại | pass | BACK đóng bàn phím trước; BACK trên thanh app bar quay về login. Từ quên mật khẩu, quay lại login vẫn giữ dữ liệu login trước đó. Form đăng ký khách và chủ sân bị làm mới khi mở lại (các trường trống; giấy tờ chủ sân không còn). BACK ở login khi bàn phím đã đóng rời app; mở lại bằng `monkey` đưa về login. |
| 6. Landscape login và đăng ký | pass | Cả hai form nằm trong vùng cuộn. Sau swipe lên trong form, các nút cuối (liên kết login và CTA đăng ký) hiện trong UI tree và có bounds trong viewport; không có control nào bị mắc kẹt ngoài vùng cuộn. |
| 7. Keyboard mở trên login và đăng ký portrait | pass | Khi bàn phím mở, trường focus và nút chính vẫn có trong UI tree; màn form có thể cuộn. |
| 8. HOME, xoay khi nhập, force-stop/relaunch | pass | Email và mật khẩu login sống sót qua HOME rồi mở lại bằng `monkey`. Email đang focus vẫn còn sau khi xoay sang landscape và về portrait. Sau `am force-stop` và mở lại, login trống; mật khẩu không được lưu. |
| 9. Google Web Client ID | pass (cấu hình cần lưu ý) | Nút hiển thị `Thiếu cấu hình Google Web Client ID`, đúng với build dev không truyền define này. `AuthRepositoryImpl` đọc `String.fromEnvironment('GOOGLE_WEB_CLIENT_ID')`; `env/dev.json` và `env/prod.json` đều không có khóa này. README hướng dẫn truyền `--dart-define` hoặc thêm khóa vào file define. Vì vậy repository chưa cấu hình ID trong cả hai file env; pipeline build riêng có thể truyền define, điều đó chưa được kiểm tra ở lượt QA này. |

## Issue files

- `qa/issues/10-login-stale-server-error.md` — low: banner lỗi máy chủ cũ còn sau khi email bị sửa thành giá trị không hợp lệ (tái hiện hai lần).

Không ghi nhận defect khác đủ điều kiện lập issue. Không mở được thành công đăng nhập/đăng ký hoặc gửi link vì backend không chạy; đây là giới hạn môi trường, còn trạng thái lỗi của UI đã được quan sát.

## Logcat mẫu

```text
11-09 01:47:56.490 I/flutter (12229): uri: http://10.0.2.2:8080/api/auth/login
11-09 01:47:58.563 I/flutter (12229): *** DioException ***:
11-09 01:47:58.564 I/flutter (12229): Error: SocketException: Connection refused (OS Error: Connection refused, errno = 111), address = 10.0.2.2
```

Không thấy `FATAL EXCEPTION` của process `com.bro73.fcourt` trong lần gửi login; stack trace `AndroidRuntime` lọc được thuộc tiến trình công cụ UI automation, không phải app.

## Source đã đọc

`lib/features/auth/presentation/pages/login_page.dart`, `forgot_password_page.dart`, `register_customer_page.dart`, `register_owner_page.dart`, `lib/features/auth/presentation/validators.dart`, `lib/features/auth/presentation/bloc/login_bloc.dart`, `lib/features/auth/data/repositories/auth_repository_impl.dart`, `lib/core/config/app_config.dart`, `env/dev.json`, `env/prod.json`, và phần cấu hình Google trong `README.md`.

## Cài đặt emulator

Đã đọc giá trị ban đầu trước khi đổi: `font_scale=1.0`, `accelerometer_rotation=1`, `user_rotation=0`, night mode `no`. Lượt này chỉ đổi xoay màn hình tạm thời: `accelerometer_rotation=0`, `user_rotation=1` cho landscape; đã khôi phục `accelerometer_rotation=1`, `user_rotation=0`. Không đổi font scale, night mode hoặc display size. Đã đọc lại cuối lượt: `font_scale=1.0`, `accelerometer_rotation=1`, `user_rotation=0`, night mode `no`.
