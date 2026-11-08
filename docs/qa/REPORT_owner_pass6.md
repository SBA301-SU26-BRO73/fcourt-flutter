# Báo cáo QA chủ sân (ADMIN) — pass 6

Thiết bị: `emulator-5554`; ứng dụng `com.bro73.fcourt`; đăng nhập được tài khoản `owner01@demo.com` (màn hồ sơ xác nhận vai trò Chủ sân). Không lưu hoặc tạo dữ liệu mới. Chỉ ghi lỗi đã tái hiện ít nhất hai lần vào danh sách issue; lượt này chưa có lỗi nào đủ điều kiện đó.

| Màn hình / luồng | Kết quả | Ghi nhận |
|---|---|---|
| Trang chủ và menu Chủ sân | pass | Trang chủ hiện ba nút: Gói dịch vụ, Quản lý đơn đặt sân, Quản lý voucher. “Quản lý cụm sân” là tiêu đề không bấm được; danh sách nút không cuộn và không có entry quản lý chi nhánh. Ảnh: `qa/screens/owner-home.png`. |
| Danh sách chi nhánh | not reached | Không có entry bấm được từ trang chủ; không dùng deep link theo chỉ dẫn. |
| Tạo chi nhánh: validation trống, số điện thoại sai, thông tin ngân hàng | not reached | Phụ thuộc danh sách chi nhánh. |
| Sửa chi nhánh hiện có | not reached | Phụ thuộc danh sách chi nhánh. |
| Danh sách sân và form sân | not reached | Phụ thuộc danh sách chi nhánh. |
| Mẫu khung giờ 30 phút, ma trận xem trước | not reached | Không có đường UI tới danh sách sân. |
| Giá giờ cao điểm; giá ngày thường/cuối tuần | not reached | Không có đường UI tới danh sách sân. |
| Ngoài giờ phục vụ / khóa sân toàn bộ; lịch tuần | not reached | Không có đường UI tới danh sách sân. |
| Thư viện ảnh chi nhánh | not reached | Phụ thuộc chi nhánh; không tải ảnh. |
| Voucher — danh sách | error-state ok | Màn hình mở; hiển thị `0 voucher`, `Lỗi máy chủ (502)` và nút `Thử lại`. Ảnh: `qa/screens/voucher-list.png`. Backend voucher được khai báo đang chạy; trạng thái 502 chưa được tái hiện hai lần để kết luận lỗi ứng dụng. |
| Voucher — form tạo, submit trống | pass (đã mở form; validation chưa xác nhận) | Form có mã, loại giảm giá, giá trị và ngày hiệu lực; không lưu. Ảnh: `qa/screens/voucher-form.png`. Các kiểm tra phần trăm >100 và ngày kết thúc trước ngày bắt đầu chưa thực hiện được. |
| Quản lý nhân viên và form tạo | not reached | Không có entry trên trang chủ; không dùng deep link. |
| Gói dịch vụ — gói hiện tại | pass | Hiển thị gói Chuyên nghiệp, hiệu lực, ngày hết hạn, hạn mức và trạng thái đang có hiệu lực. Ảnh: `qa/screens/subscription-current.png`. |
| Gói dịch vụ — so sánh các gói | pass | Danh sách gói và giá tải được. Ảnh: `qa/screens/subscription-plans.png`. |
| Dashboard / analytics, biểu đồ, lọc ngày, export | not reached | Từ dashboard cần bắt đầu ở danh sách chi nhánh; không có entry trực tiếp trên trang chủ. Không export. |
| Quản lý đặt sân | error-state ok | Hiển thị `Lỗi máy chủ (502)` cùng nút `Thử lại`; retry giữ màn hình và không crash. Đây là dịch vụ đang DOWN theo đề bài, nên chỉ đánh giá lỗi giao diện. Ảnh: `qa/screens/booking-error.png`. |
| Giao dịch / hoàn tiền | not reached | Không thấy entry điều hướng trên các màn hình đã mở; booking/payment đang DOWN. |

## Issues

Không tạo `qa/issues/NN-*.md`: chưa có lỗi nào được tái hiện hai lần. Các màn hình chưa tới được không được ghi thành defect.

## Cài đặt thiết bị

Đọc trước và sau phiên: `font_scale=1.0`, `accelerometer_rotation=1`, `user_rotation=0`, night mode `no`. Không thay đổi cài đặt; không cần khôi phục. Chỉ dùng emulator `emulator-5554`; tối đa 30 ảnh chụp.

## Nguồn đã đọc

`lib/app/router.dart`, `lib/features/auth/presentation/pages/home_page.dart`, `lib/app/admin_facility_routes.dart`. HomePage hiện chỉ tạo ba nút thao tác cho `UserRole.admin`; router khai báo các route quản lý chi nhánh, sân, ảnh, báo cáo, nhân viên, nhưng không tạo đường bấm từ trang chủ để vào các mục đó.
