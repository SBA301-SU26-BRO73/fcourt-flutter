# SCRUM-13 — [Flutter: Admin] Dashboard

Feature: `lib/features/admin_dashboard/`. Màn hình: `AdminDashboardScreen`.
Danh sách chi nhánh cho dropdown dùng use case `GetBranches` của
`admin_facility` (cùng facility-service, không lặp code gọi API).

## Chạy thử

```powershell
flutter run --dart-define-from-file=env/dev.json --route=/admin/dashboard
```

`REPORTING_BASE_URL` (mặc định `http://10.0.2.2:8084` trong `env/dev.json`)
trỏ tới reporting-service; bỏ trống thì dùng `API_BASE_URL`. Reporting kiểm
tra quyền sở hữu chi nhánh bằng cách gọi facility-service với cùng bearer token,
nên facility-service cũng phải chạy. Dashboard có nút sang `/admin/branches`
và danh sách chi nhánh có nút sang dashboard.

## Luồng sử dụng

- Lưới 4 thẻ: **Tổng doanh thu** dạng rút gọn (`15.5M đ`, kèm "Hôm nay
  850K đ"), **Lượt đặt sân**, **Sân hoạt động** (`active/total`), **Tỷ lệ lấp
  đầy** (`72.5%`).
- **PieChart** (fl_chart) trạng thái đặt sân: Đã xác nhận (xanh), Chờ duyệt
  (vàng), Đã hủy (đỏ), nhãn %, chú thích kèm số lượng; chưa có booking thì hiện
  "Chưa có lượt đặt sân".
- Dropdown **Chi nhánh** ("Tất cả chi nhánh" = không gửi `branchId`): đổi là
  gọi lại API ngay; phản hồi của lựa chọn cũ về muộn bị bỏ qua.
- **Shimmer**: lần tải đầu hiện khung xương 4 thẻ + biểu đồ; khi đổi chi nhánh
  chỉ phủ shimmer lên các thẻ, biểu đồ giữ nguyên để fl_chart chuyển động mượt
  (600 ms, easeOutCubic) sang số liệu mới. Kéo để tải lại; lỗi có nút "Thử lại".
  Lỗi tải danh sách chi nhánh không chặn số liệu tổng.

Định dạng rút gọn (`formatCompactVnd`): K/M/B, 1 chữ số thập phân, bỏ `.0`,
làm tròn sát ngưỡng lên đơn vị kế (999 950 → `1M đ`).

## API đã tích hợp

`GET /api/admin/dashboard/stats?branchId={id}` (reporting-service, JWT ADMIN):

```json
{"branchId":3,"totalRevenue":15500000,"todayRevenue":850000,"totalBookings":42,
 "bookingStatusCounts":{"CONFIRMED":30,"PENDING":8,"CANCELLED":4},
 "activeCourts":6,"totalCourts":8,"occupancyRate":0.725,"generatedAt":"..."}
```

Số đếm thiếu trong `bookingStatusCounts` coi là 0; sai kiểu báo dữ liệu
không hợp lệ. `totalRevenue`/`todayRevenue` là BigDecimal (`15500000.00`),
`occupancyRate` là double 0..1 (4 chữ số thập phân, app vẫn giới hạn 0..1),
`branchId` là `null` khi xem tất cả. 403 "Branch access denied" (chi nhánh của
chủ khác) → "Bạn không có quyền xem số liệu của chi nhánh này"; 503 (facility
không phản hồi) → "Chưa lấy được thông tin chi nhánh, vui lòng thử lại sau".

## Phần chờ tích hợp

| Nội dung | Hiện tại trên app | Cần từ backend / task khác |
| --- | --- | --- |
| Số liệu booking thật | Hiển thị những gì reporting trả về | Booking/payment phát sự kiện cho reporting |
| Lọc theo khoảng thời gian | Chưa có (contract không có tham số ngày) | Mở rộng API nếu cần |
| Đăng nhập | Như SCRUM-15 | SCRUM-7 |

## Kiểm chứng chung (cả nhánh SCRUM-15/17/19/13)

Kiểm chứng local ngày 31/10/2026, Windows 11, Flutter 3.47.7:

- `flutter pub get`: thành công. Thêm `fl_chart ^1.3.0`, `shimmer ^4.0.0`.
- `dart format --output=none --set-exit-if-changed` trên mọi file Dart nhánh
  này thêm/sửa (trừ `lib/app/router.dart`): 76 file, 0 thay đổi. Chạy trên
  toàn bộ `lib test` vẫn báo 6 file **có sẵn trên `dev`** chưa format
  (`router.dart`, `app_theme.dart`, `auth_interceptor.dart`,
  `token_storage.dart`, `health_page.dart`, `auth_interceptor_test.dart`);
  không format lại để tránh xung đột với nhánh khác.
- `flutter analyze`: No issues found.
- `flutter test`: 101 test pass (gồm test cũ của khung app), trong đó test mới
  cho contract HTTP bằng `FakeAdapter`, bloc, widget, sinh slot, định dạng tiền
  rút gọn, dashboard (shimmer, 4 thẻ, PieChart, đổi chi nhánh) và test mở từng
  route admin trên `FcourtApp`.
- `flutter build apk --debug --dart-define-from-file=env/dev.json`: build
  thành công `build/app/outputs/flutter-apk/app-debug.apk`.
- **Chưa chạy trên máy ảo/thiết bị Android** (máy kiểm chứng không có
  emulator) và **chưa gọi backend thật**: chưa có màn đăng nhập (SCRUM-7) để
  lấy JWT ADMIN, và backend SCRUM-14/16/18/12 đang được làm song song. Test
  HTTP dùng adapter giả theo `CONTRACTS.md`, không thay thế kiểm thử end-to-end.

Task: https://bro73.atlassian.net/browse/SCRUM-13

### Đối chiếu với backend thật (31/10/2026)

Đã so từng model với record của `fcourt-backend`
(`feature/Tuan-SCRUM-14-facility-reporting`: `BranchResponse/Request`,
`CourtResponse/Request`, `TemplateDtos`, `DashboardService.DashboardStats`,
`ApiErrors`) và seed V2. Test `FakeAdapter` dùng JSON đúng dạng backend, gồm
chi nhánh/sân seed nhiều trường `null`. Các điểm đã sửa: giá sân `null`, giữ
`imageUrl`/tọa độ/`slotDurationMinutes` khi PUT, độ dài và định dạng số điện
thoại theo `@Size`/`@Pattern`, đoán `bankBin` theo `bankName`, thông báo lỗi
tiếng Việt cho 400 `errors`/403/404/409/503. Chưa gọi backend đang chạy.
