# Báo cáo QA customer pass 3 — FCOURT Android

Thiết bị: `emulator-5554`, app `com.bro73.fcourt`, tài khoản customer fixture đã đăng nhập sẵn. Thời điểm bắt đầu: 02:27:09; dừng kiểm tra chủ động lúc 02:31:50 (trước mốc dừng 6 phút). Backend auth, facility, discovery đang chạy; booking, slot-hold và các dịch vụ khác được thông báo là không chạy.

| Kịch bản | Kết quả | Ghi nhận |
|---|---|---|
| 1. Tìm sân | pass một phần | Danh sách thực có 25 chi nhánh, gồm Sân Cầu Lông Ba Đình; ban đầu trạng thái rỗng trong lúc tải, sau đó danh sách xuất hiện. Mở bộ lọc thấy môn, khoảng giá, khu vực và khung giờ; chưa nhập tìm kiếm/áp dụng lọc hoặc kiểm tra empty result và cuộn hết danh sách vì giới hạn thời gian. Ảnh: `qa/screens/discovery_empty.png` (ảnh trạng thái tải ban đầu). |
| 2. Chi tiết chi nhánh | pass một phần | Mở được chi tiết Ba Đình, địa chỉ, 2 sân, giá tham khảo từ 20.000đ/slot, tiện ích; tab đánh giá hiển thị 0 đánh giá. Vị trí báo chi nhánh chưa có tọa độ GPS hợp lệ; chưa xác nhận ảnh/map thực tế. Nút Đặt sân hiện thông báo danh sách sân chưa cập nhật. Ảnh: `qa/screens/branch_details.png`. |
| 3. Chọn khung giờ | not reached | Không có danh sách sân để chọn từ chi tiết nên không vào được slot picker; lưới trạng thái, giá tổng, chọn/xóa slot và đổi ngày chưa kiểm tra. Dù discovery đang hoạt động, app hiện placeholder “danh sách sân chưa được cập nhật”; chưa xác định đây là dữ liệu fixture hay hạn chế của endpoint/build. |
| 4. Tiếp tục booking/hold | not reached | Luồng không tới bước giữ sân/đặt booking do thiếu danh sách sân và slot picker. Không kiểm tra được lỗi từ booking/slot-hold service. Nút “Đặt sân ngay” dừng tại thông báo tiếng Việt, không treo spinner. |
| 5. Lịch sử đặt sân | pass (dịch vụ thiếu) | Booking history hiển thị “Lỗi máy chủ (502)” và nút “Thử lại”, không crash/không spinner vô hạn. Đây là lỗi dự kiến do booking service không chạy, xử lý lỗi rõ ràng. Ảnh: `qa/screens/booking_history_error.png`. |
| 6. Hồ sơ / đổi mật khẩu / đăng xuất | pass một phần | Hồ sơ hiển thị email customer01@demo.com và vai trò Khách hàng. Gửi form đổi mật khẩu rỗng đưa ra lỗi bắt buộc cho cả ba trường. Đăng xuất về màn hình đăng nhập; BACK từ đăng nhập về launcher, không thấy màn hình customer đã đăng nhập. Các giá trị đổi mật khẩu hợp lệ/mismatch chưa thử. Ảnh: `qa/screens/profile.png`, `qa/screens/change_password.png`, `qa/screens/logged_out.png`. |
| 7. Cỡ chữ, ngang, tối | pass một phần | Đã thử font scale 1.3, landscape và night mode `yes` khi đang ở hồ sơ; chụp `qa/screens/profile_layout.png`. Chưa rà soát mọi màn hình ở cả ba cấu hình do giới hạn thời gian. |

## Issues

Không tạo issue: chưa xác nhận được defect tái hiện hai lần. Lỗi 502 lịch sử là do booking service được xác nhận đang tắt và UI có thông báo/retry; thông báo tại nút đặt sân là placeholder nhìn thấy được, nhưng chưa đủ bằng chứng để quy nguyên nhân thành lỗi app thay vì dữ liệu/endpoint.

## Source đã xem

- `lib/src/features/customer_discovery/presentation/screens/branch_detail_screen.dart` — phần danh sách sân chưa cập nhật và hành vi nút đặt sân hiện thông báo placeholder.
- `lib/features/booking_history/presentation/booking_history_screen.dart` — màn lịch sử đặt sân.
- `lib/features/auth/presentation/pages/profile_page.dart` — hồ sơ và thao tác đổi mật khẩu/đăng xuất.

## Cài đặt thiết bị

Đọc giá trị ban đầu trước khi đổi: `font_scale=1.0`, `accelerometer_rotation=0`, `user_rotation=0`, night mode `no`. Đã thử font scale `1.3`, tắt tự xoay và đặt xoay ngang `1`, bật night mode `yes`; cuối lượt xác nhận và khôi phục `font_scale=1.0`, `accelerometer_rotation=1`, `user_rotation=0`, night mode `no`.
