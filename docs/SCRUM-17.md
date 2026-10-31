# SCRUM-17 — [Flutter: Admin] Sân

Feature: `lib/features/admin_facility/`. Màn hình: `CourtListScreen`,
`CourtFormScreen`.

## Chạy thử

```powershell
flutter run --dart-define-from-file=env/dev.json --route=/admin/branches/1/courts
```

Cấu hình `FACILITY_BASE_URL` như `docs/SCRUM-15.md`. Thường vào từ thẻ chi
nhánh trong `/admin/branches`.

## Luồng sử dụng

- `/admin/branches/:branchId/courts`: dropdown **Chi nhánh** ở đầu màn hình
  để lọc; đổi chi nhánh tải lại sân ngay, phản hồi của chi nhánh cũ về muộn bị
  bỏ qua. Lưới **2 cột**, mỗi thẻ có nhãn trạng thái **Hoạt động** (xanh lá),
  **Bảo trì** (vàng), **Đang đóng** (xám), tên sân, loại sân, giá/giờ dạng
  `120.000 đ/giờ`, nút mẫu khung giờ (SCRUM-19) và **Switch Bảo trì**.
- Switch gọi `PATCH /status` (bật → `MAINTENANCE`, tắt → `ACTIVE`), khóa
  Switch trong lúc chờ, cập nhật nhãn theo response và hiện SnackBar. Lỗi thì
  giữ trạng thái cũ, SnackBar màu lỗi.
- `/admin/courts/new?branchId=`, `/admin/courts/:courtId/edit`: tên sân, loại
  sân (Cầu lông, Pickleball, Tennis), giá mặc định mỗi giờ (> 0, chỉ nhận số),
  mô tả, công tắc "Đang bảo trì". Lưu thành công trả sân về lưới: sân được
  thêm/cập nhật ngay không cần gọi lại API, kèm SnackBar.

## API đã tích hợp (facility-service, JWT ADMIN)

| Thao tác | Endpoint |
| --- | --- |
| Sân theo chi nhánh | `GET /api/admin/branches/{branchId}/courts` |
| Tạo sân | `POST /api/admin/branches/{branchId}/courts` → 201 |
| Chi tiết / sửa | `GET` / `PUT /api/admin/courts/{id}` |
| Bật/tắt bảo trì | `PATCH /api/admin/courts/{id}/status` body `{status}` |

CourtRequest: `{name, courtTypeId, description|null, defaultPricePerHour,
status}`. `defaultPricePerHour` nhận cả số nguyên lẫn số thực (BigDecimal) và
làm tròn về đồng. Trùng tên sân trong chi nhánh (400) hoặc vượt giới hạn gói
(403) hiển thị `detail` của server. Trạng thái lạ → báo dữ liệu không hợp lệ.

## Phần chờ tích hợp

| Nội dung | Hiện tại trên app | Cần từ backend / task khác |
| --- | --- | --- |
| Danh mục loại sân | `CourtTypeLocalDataSource`: Pickleball=1, Tennis=3, Cầu lông=6 (seed subscription-service, giống SCRUM-21) | API catalog loại sân (SCRUM-10/11); chỉ cần thay data source |
| Ảnh sân | Không gửi `imageUrl` | Upload ảnh (ngoài AC) |
| Xóa sân | Chưa có nút xóa (`DELETE` có trong contract) | Không thuộc AC của SCRUM-17 |
| Đăng nhập | Như SCRUM-15 | SCRUM-7 |

## Kiểm chứng

Xem "Kiểm chứng chung" trong `docs/SCRUM-13.md`. Test riêng: contract
court trong `facility_repositories_test.dart`; `facility_blocs_test.dart`
(tải, đổi chi nhánh với phản hồi cũ, Switch thành công/lỗi, upsert, giá ≤ 0);
`facility_screens_test.dart` (lưới 2 cột, 3 nhãn trạng thái, Switch + SnackBar,
sân mới hiện ngay, validation form, dropdown 3 loại sân).

Task: https://bro73.atlassian.net/browse/SCRUM-17
