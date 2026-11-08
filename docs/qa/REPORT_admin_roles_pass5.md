# Báo cáo QA giao diện Android – pass 5 (SUPER ADMIN / OWNER / STAFF)

Thời gian chạy: 09/11/2026, bắt đầu 02:56:57; dừng kiểm thử lúc 03:02:57 theo giới hạn 6 phút. Thiết bị duy nhất: `emulator-5554` (Pixel 8, 1080×2400). Backend cục bộ đã khai báo chạy auth, facility, subscription, reporting, voucher, staff-operations; booking, slot-hold, payment, POS, notification, discovery đang dừng. Chỉ sử dụng backend cục bộ theo cấu hình của ứng dụng.

## SUPER ADMIN

| Màn hình / thao tác | Kết quả | Ghi chú |
|---|---|---|
| Đăng nhập | pass | Đăng nhập được với fixture sau khi xác minh email và 12 ký tự mật khẩu trong cây UI. |
| Home và menu | pass | Home hiển thị Quản lý danh mục và Thống kê nền tảng. |
| Hồ sơ / đăng xuất | pass | Menu tài khoản mở, đăng xuất trở về login. |
| Danh sách chủ sân chờ duyệt và chi tiết hồ sơ | chưa tới | Không thấy mục này trong home; dừng theo mốc thời gian. Không duyệt/từ chối ai. |
| Quản lý danh mục – loại sân | pass | Danh sách hiển thị các loại sân. |
| Quản lý danh mục – gói dịch vụ | pass | Chuyển được tab gói dịch vụ. |
| Form sửa gói dịch vụ | mở được; chưa kiểm tra validation | Form có các trường nhập; không lưu thay đổi. Form tạo mới chưa tới. |
| Tổng quan nền tảng | chưa tới | Mục có trên home; thao tác trước đó đã đưa về launcher nên không xác nhận nội dung màn hình. |

## OWNER (ADMIN)

| Màn hình / thao tác | Kết quả | Ghi chú |
|---|---|---|
| Đăng nhập | pass | Home chào “Admin Một”. |
| Home và menu | pass | Hiển thị Gói dịch vụ, Quản lý đơn đặt sân, Quản lý voucher; tiêu đề Quản lý cụm sân. |
| Quản lý cụm sân / chi nhánh | chưa tới | Chạm tiêu đề không điều hướng; mục chi tiết không có trong các nút home đã đọc. |
| Gói dịch vụ / so sánh | chưa tới | Chỉ xác nhận mục trên home. |
| Đơn đặt sân, giao dịch / hoàn tiền | chưa tới | Chỉ xác nhận mục trên home. Trạng thái xử lý khi booking/payment dừng chưa được quan sát. |
| Voucher và form | chưa tới | Chỉ xác nhận mục trên home. |
| Courts, slot template, giá, khóa sân, nhân viên, dashboard / analytics | chưa tới | Chưa điều hướng tới các màn hình này trong thời gian còn lại. |

## STAFF

| Màn hình / thao tác | Kết quả | Ghi chú |
|---|---|---|
| Đăng nhập, home/menu, lịch hôm nay, QR scanner, nhập mã, walk-in, POS | chưa tới | Không còn thời gian sau mốc dừng bắt buộc ở phút thứ 6. |

## Vấn đề và ghi chú

- Không tạo issue: trong phần đã tới không có lỗi giao diện nào được tái hiện hai lần.
- Login có thông báo “Thiếu cấu hình Google Web Client ID” khi chạm Google. Chỉ ghi nhận trạng thái thực tế, chưa xác định cấu hình dev/prod để kết luận lỗi sản phẩm. Source liên quan: `lib/features/auth/data/repositories/auth_repository_impl.dart`.
- File source đã tra cứu để định vị các màn hình: `lib/features/auth/presentation/pages/home_page.dart`, `lib/features/catalog/presentation/pages/catalog_page.dart`, `lib/features/super_admin/presentation/pages/super_admin_overview_screen.dart`, và `lib/features/super_admin/data/datasources/super_admin_remote_data_source.dart`.
- Ảnh được lưu dưới `qa/screens/pass5-*.png`. Không có tệp trong `qa/issues/` cho pass này.
- Không thể đánh giá cách các màn hình xử lý lỗi dịch vụ dừng hoặc 401 vì chưa mở được các màn hình gọi booking/payment hay các màn hình liên quan khác.

## Thay đổi thiết bị

Không đổi system setting. Đọc được giá trị ban đầu font scale `1.0`, accelerometer rotation `1`, user rotation `0`. Night mode không được đổi (không đọc giá trị riêng trong lượt này). Không chạy layout checks font scale/landscape; không cần khôi phục setting nào.

