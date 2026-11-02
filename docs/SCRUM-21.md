# SCRUM-21 — Customer discovery

Feature: `lib/src/features/customer_discovery/`.

## Chạy thử

```powershell
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```

Discovery gọi `http://10.0.2.2:8085` từ Android emulator. `API_BASE_URL`
vẫn dành cho các service còn lại. Nếu qua gateway, đặt `DISCOVERY_BASE_URL`
thành địa chỉ gateway; nếu không khai báo, app dùng `API_BASE_URL`.
Trên điện thoại thật, truyền địa chỉ LAN của host bằng dart-define.

```powershell
flutter run --dart-define-from-file=env/dev.json --dart-define=DISCOVERY_BASE_URL=http://192.168.1.10:8085
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=env/dev.json
```

Khởi động backend theo `discovery-service/README.md` trong repo
`fcourt-backend`, nhánh `feature/Dang-discovery-service` (SCRUM-20), hoặc
nhánh `feature/Dang-discovery-available-slots` kế thừa contract này. Backend
phải nhận snapshot Kafka trước khi tìm kiếm có kết quả. Không đưa dữ liệu
mẫu vào app để thay thế dữ liệu thật.

## Luồng sử dụng

- `/`: banner thể thao, tìm nhanh tên/địa chỉ, danh mục cuộn ngang.
- `/branches?query=...&sport=tennis`: tìm kiếm, bộ lọc môn, kéo để tải lại,
  phân trang bằng nút Xem thêm. Đổi bộ lọc về trang 0; debounce 300 ms;
  phản hồi cũ không ghi đè kết quả mới. Thử lại trang sau giữ danh sách hiện có.
- `/branches/:id`: mở đúng dữ liệu chi nhánh từ thẻ đã chọn; quay lại giữ
  từ khóa và kết quả. Khi mở trực tiếp URL không có dữ liệu, thông báo mở
  từ danh sách vì backend chưa có endpoint chi tiết. Không quét toàn bộ
  tập dữ liệu để giả lập endpoint tra cứu ID.
- `/health`: giữ lại màn hình kiểm tra kết nối của khung app.

Giao diện tham chiếu nhóm component home/branch của frontend React tại
`Source_SBA/group-project-sba301_fcourt/frontend`: gradient tím → xanh,
thẻ bo góc, banner thể thao, khám phá theo môn, giá và thông tin chi nhánh.
App dùng widget Material 3 và artwork sân dạng hình học; artwork là ảnh
trang trí, không được ghi nhận là ảnh thực tế của chi nhánh.

## API đã tích hợp

`GET /api/public/branches`, không JWT, response trực tiếp có `content`,
`page`, `size`, `totalElements`, `totalPages`. App gửi `query`, `courtTypeId`,
`page` bắt đầu từ 0 và `size=12`. Không dùng API monolith `/branches/search`
hoặc response bọc trong `data` của frontend cũ.

ID môn theo `subscription-service/database/V2__seed_sample_data.sql`:
Cầu lông=6, Pickleball=1, Tennis=3. Môi trường có catalog khác cần truyền
`BADMINTON_TYPE_ID`, `PICKLEBALL_TYPE_ID`, `TENNIS_TYPE_ID` khi build.
Đây là cấu hình tạm trong khi chờ API catalog, không suy đoán ID theo vị trí.

## Phần chờ API — theo lựa chọn của người thực hiện

SCRUM-20 chưa có các trường/endpoint sau, nên chưa thể nghiệm thu đầy đủ:

| Nội dung | Hiện tại trên app | Cần từ backend / task tiếp theo |
| --- | --- | --- |
| Ảnh bìa | Artwork và nhãn ảnh chưa cập nhật | URL ảnh bìa public |
| Rating | Chưa có đánh giá | Rating tổng hợp và số review (SCRUM-104) |
| Tiện ích | Wifi/bãi xe/quầy nước: chưa cập nhật | Danh sách tiện ích được xác nhận |
| Sân con | Số lượng sân thật, chưa có danh sách | Public branch detail và danh sách court ID/name/type/status |
| Khoảng cách | Hiển thị distanceKm nếu có; hiện chưa có khoảng cách | Tích hợp vị trí, gửi cặp GPS; ngoài phạm vi task này |
| Đặt sân ngay | Thông báo chưa thể chọn lịch | Court IDs thật và màn hình chọn slot SCRUM-23 |
| Catalog loại sân | ID từ seed có thể cấu hình | Public court types API |

Không hiển thị rating, khoảng cách, tiện ích hoặc sân con giả. Nút đặt sân
không tạo booking hay chuyển đến route chưa tồn tại. Giá là khoảng giá
tham khảo từ API, không phải báo giá/khung giờ còn trống thời gian thực.

## Review

Kiểm chứng local ngày 27/10/2026 (Asia/Saigon), Flutter 3.47.7 / Dart 3.13.5:

- `flutter pub get`: thành công, không thay đổi dependency hay lockfile.
- `flutter analyze --no-pub`: không có issue.
- `flutter test --no-pub`: 22 tests pass, gồm kiểm thử cũ và 9 test discovery
  mới cho contract HTTP, null/malformed/error, debounce, race, pagination,
  đóng Cubit và điều hướng.
- `flutter build apk --debug --no-pub --dart-define-from-file=env/dev.json`:
  chưa build được vì máy chưa có Android SDK. Chưa chạy emulator/thiết bị thật.
- `git diff --check`: pass.
- HTTP smoke với service thật (JAR hiện có trên nhánh slots kế thừa SCRUM-20,
  PostgreSQL/Kafka/Redis thật, sample `examples/branch-updated.json`): fuzzy
  `query=sunrize`, filter `courtTypeId=1`, filter không khớp `courtTypeId=6`,
  query không có kết quả đều trả response phân trang đúng contract. Đây là
  kiểm tra HTTP bằng Python, chưa chạy Postman GUI hoặc app trên Android.

Khi chạy JAR local trên máy này, truyền `-Duser.timezone=Asia/Ho_Chi_Minh`
để tránh PostgreSQL từ chối alias timezone `Asia/Saigon` của JVM Windows.
Tiến trình/containers phục vụ smoke được dừng sau kiểm chứng; không sửa
mã nguồn backend.

Các test HTTP của repository dùng Dio adapter giả theo contract SCRUM-20;
widget tests không thay thế kiểm thử Android với backend thật.

Task: https://bro73.atlassian.net/browse/SCRUM-21

Request Review: https://bro73.atlassian.net/browse/SCRUM-142

Người thực hiện cho phép code sau khi tạo Request Review; reviewer Jira là
Từ Phúc Nguyên, reviewer GitHub là `donan2k5`. Không tự xác nhận approval
hay merge. Diff của ba màn hình cùng tests vượt gợi ý ~300 dòng; các commit
tách riêng data/domain, UI và kiểm thử để reviewer kiểm tra từng giai đoạn.
