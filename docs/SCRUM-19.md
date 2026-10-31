# SCRUM-19 — [Flutter: Admin] Mẫu khung giờ (Slot)

Feature: `lib/features/admin_facility/`. Màn hình: `TimeSlotTemplateScreen`,
widget `SlotMatrixPreview`; logic thuần Dart ở
`domain/entities/slot_matrix.dart`.

## Chạy thử

```powershell
flutter run --dart-define-from-file=env/dev.json --route=/admin/courts/1/slot-template
```

Thường vào từ nút "Mẫu khung giờ" trên thẻ sân (SCRUM-17).

## Luồng sử dụng

- Màn hình tải sân (`GET /api/admin/courts/{id}`) rồi chi nhánh của sân
  (`GET /api/admin/branches/{branchId}`) để lấy giờ mở/đóng cửa.
- Mặc định: bắt đầu = giờ mở cửa, kết thúc = giờ đóng cửa, **bước 30 phút
  (chuẩn, cố định vì backend chỉ nhận 30)**, giá mỗi slot = giá giờ × 30/60,
  áp dụng cả 7 ngày (chip CN, T2…T7).
- **SlotMatrixPreview**: lưới cuộn hiển thị mọi slot trong ngày
  (`06:00–06:30`, `06:30–07:00`, …) kèm giá, tính ngay trên máy khi đổi
  giờ/giá; tiêu đề "Xem trước: N slot/ngày". Tối đa 48 slot/ngày.
- Cảnh báo (khung vàng) khi **giờ kết thúc sớm hơn hoặc bằng giờ bắt đầu**,
  khi khung giờ nằm ngoài giờ mở cửa chi nhánh, hoặc tổng thời gian không chia
  hết cho 30 phút; khi đó bản xem trước rỗng và nút áp dụng bị khóa. Nút cũng
  khóa khi giá ≤ 0 hoặc chưa chọn ngày.
- **Áp dụng cho sân** → hộp thoại xác nhận (số slot, khung giờ, giá, các ngày,
  cảnh báo mẫu cũ của các ngày đó bị thay thế) → gọi `apply-template` → SnackBar
  "Đã áp dụng N slot cho M ngày trong tuần" hoặc thông báo lỗi của server.

## API đã tích hợp

`POST /api/admin/courts/{courtId}/apply-template` với ApplyTemplateRequest:

```json
{"startTime":"06:00","endTime":"22:00","durationMinutes":30,"price":60000,"daysOfWeek":[0,1,2,3,4,5,6]}
```

Response đọc `courtId`, `daysOfWeek`, `totalSlots` (danh sách `slots` không
cần cho màn hình). Bản xem trước dùng cùng quy tắc với backend (end > start,
nằm trong giờ chi nhánh, chia hết cho 30, giá mặc định = giá giờ × 30/60) nên
không gọi `.../time-slot-templates/preview`; việc lưu luôn đi qua backend và
backend vẫn là nơi kiểm tra cuối (400 → hiển thị `detail`).

## Phần chờ tích hợp

| Nội dung | Hiện tại trên app | Ghi chú |
| --- | --- | --- |
| Bước khác 30 phút | Hiển thị cố định "30 phút (chuẩn)" | Backend chỉ chấp nhận 30 |
| Hệ số giá (`priceMultiplier`) | Không dùng; gửi `price` cụ thể | Có thể thêm giá giờ cao điểm sau |
| Xem mẫu đang áp dụng | Chưa hiển thị `GET .../time-slot-templates` | Ngoài AC |
| Đăng nhập | Như SCRUM-15 | SCRUM-7 |

## Kiểm chứng

Xem "Kiểm chứng chung" trong `docs/SCRUM-13.md`. Test riêng:
`facility_rules_test.dart` (06:00–06:30…, 47 slot cho 00:00–23:30 ≤ 48, giờ
ngược/lệch bước → rỗng, ngoài giờ chi nhánh, giá mặc định); contract
`apply-template` và lỗi 400 trong `facility_repositories_test.dart`;
`facility_blocs_test.dart` (mặc định 32 slot, cảnh báo, request đúng ngày/giá,
lỗi); `facility_screens_test.dart` (lưới giá, đổi giá cập nhật ngay, cảnh báo +
khóa nút, hộp thoại xác nhận rồi mới gọi API).

Task: https://bro73.atlassian.net/browse/SCRUM-19
