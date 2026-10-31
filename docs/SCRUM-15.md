# SCRUM-15 — [Flutter: Admin] Chi nhánh

Feature: `lib/features/admin_facility/` (data / domain / presentation).
Màn hình: `BranchListScreen`, `BranchFormScreen`.

## Chạy thử

```powershell
flutter pub get
flutter run --dart-define-from-file=env/dev.json --route=/admin/branches
```

`env/dev.json` trỏ thẳng tới từng service khi chạy trên Android emulator:

| dart-define | Mặc định trong `env/dev.json` | Ghi chú |
| --- | --- | --- |
| `API_BASE_URL` | `http://10.0.2.2:8080` | Auth/refresh token và các service khác |
| `FACILITY_BASE_URL` | `http://10.0.2.2:8083` | facility-service; bỏ trống → dùng `API_BASE_URL` |
| `REPORTING_BASE_URL` | `http://10.0.2.2:8084` | reporting-service (SCRUM-13) |

Khi đi qua gateway, chỉ cần `API_BASE_URL` (xóa hai biến còn lại). Trên điện
thoại thật, truyền địa chỉ LAN của máy chạy backend, ví dụ
`--dart-define=FACILITY_BASE_URL=http://192.168.1.10:8083`.

Backend: facility-service trong repo `fcourt-backend`, nhánh
`feature/Tuan-SCRUM-14-facility-reporting` (SCRUM-14/16/18/12).

## Luồng sử dụng

- `/admin/branches`: thẻ chi nhánh phong cách thể thao (dải gradient, icon
  vợt) gồm địa chỉ đầy đủ, giờ mở cửa `HH:mm – HH:mm`, số sân, nhãn
  "Ngừng hoạt động" nếu `status = INACTIVE`. Kéo để tải lại. Chạm thẻ → danh
  sách sân (SCRUM-17); nút bút → sửa.
- `/admin/branches/new`, `/admin/branches/:branchId/edit`: form gồm tên, địa
  chỉ, Tỉnh/Thành → Quận/Huyện (đổi tỉnh xóa quận), Phường/Xã, số điện thoại,
  TimePicker 24h giờ mở/đóng cửa, mục **Thanh toán VietQR**: dropdown ngân hàng
  (tên + BIN NAPAS 6 số), số tài khoản (chỉ nhận số, tối đa 20), tên chủ tài
  khoản.
- Tạo thành công → quay về danh sách, danh sách tải lại và hiện SnackBar
  chúc mừng có icon pháo hoa. Sửa thành công → SnackBar "Đã cập nhật...".

Validation phía app trùng `BranchRequest` của backend: tên (≤ 150), địa chỉ
(≤ 255), tỉnh bắt buộc; phường ≤ 100; **giờ đóng cửa phải sau giờ mở cửa**;
BIN 6 chữ số (chọn từ dropdown); **số tài khoản 6–20 chữ số**; tên chủ tài
khoản ≤ 150; số điện thoại (nếu nhập) 8–15 chữ số, có thể bắt đầu bằng `+`.
Bloc kiểm tra lại giờ/BIN/số tài khoản trước khi gọi API.

Lỗi server (ProblemDetail, `detail` tiếng Anh) được đổi sang tiếng Việt trong
`data/repositories/facility_failures.dart`: 400 liệt kê từng lỗi trường của
`errors` (`"field: message"`); 403 vượt giới hạn gói kèm số giới hạn hoặc chưa
có gói; **404 khi chi nhánh/sân thuộc chủ sân khác** (facility không trả
403); 409 trùng dữ liệu; 503 subscription-service không phản hồi.

**Dữ liệu seed SQL** (V2/demo_seed): `district`, `latitude`, `longitude`,
`bankBin` (và có thể cả thông tin ngân hàng) là `null`. Thẻ chi nhánh vẫn hiển
thị; form sửa tự chọn ngân hàng theo `bankName` (ví dụ "MB Bank" → 970422),
nếu không khớp thì bắt chọn lại.

## API đã tích hợp (facility-service, cần JWT ADMIN)

| Thao tác | Endpoint |
| --- | --- |
| Danh sách | `GET /api/admin/branches` → `BranchResponse[]` |
| Chi tiết (form sửa) | `GET /api/admin/branches/{id}` |
| Tạo | `POST /api/admin/branches` → 201 |
| Sửa | `PUT /api/admin/branches/{id}` |

BranchRequest gửi `openTime`/`closeTime` dạng `"HH:mm"`, trường tùy chọn rỗng
gửi `null`, không gửi `status` (backend giữ nguyên). Vì PUT **thay thế toàn bộ
bản ghi**, form gửi lại `latitude`, `longitude`, `slotDurationMinutes` (30
hoặc 60) hiện có dù chưa cho sửa. Response nhận cả `"HH:mm"` lẫn `"HH:mm:ss"`;
`name`, `address`, `city`, giờ, `status` (ACTIVE/INACTIVE) bắt buộc, sai
contract báo "Dữ liệu từ máy chủ không hợp lệ" thay vì hiển thị dữ liệu sai.

`failureFromDio` (core) đọc `detail` của RFC 7807 ngoài `message` cũ và giữ
danh sách `errors` (chuỗi hoặc `{field, message}`) trong `ServerFailure`.

## Phần chờ tích hợp

| Nội dung | Hiện tại trên app | Cần từ backend / task khác |
| --- | --- | --- |
| Đăng nhập | Chưa có màn đăng nhập; request dùng token trong `TokenStorage` | SCRUM-7 lưu access/refresh token sau login. Trước đó mọi API admin trả 401 → "Phiên đăng nhập đã hết hạn" |
| Danh mục tỉnh/quận | Danh mục tĩnh rút gọn 8 tỉnh/thành | API địa giới hành chính (backend lưu chuỗi nên không đổi contract) |
| Danh sách ngân hàng | 18 ngân hàng VietQR phổ biến kèm BIN | API danh sách ngân hàng VietQR nếu cần đầy đủ |
| Tọa độ, xóa chi nhánh | Chưa có ô nhập tọa độ (giữ nguyên giá trị cũ khi sửa); chưa có nút xóa | Không thuộc AC của SCRUM-15 |
| Điểm vào màn hình | Mở bằng `--route` hoặc từ dashboard | Menu chủ sân sau khi có login/role (SCRUM-7) |

## Kiểm chứng

Xem phần "Kiểm chứng chung" trong `docs/SCRUM-13.md` (chạy một lần cho cả
nhánh `feature/Tuan-SCRUM-15-admin-facility-dashboard`). Test riêng của task:

- `test/features/admin_facility/data/facility_repositories_test.dart`:
  đường dẫn, method, payload BranchRequest, parse `HH:mm:ss`, 400/403
  ProblemDetail + `errors`, 403 giới hạn gói, 404 chủ khác, 401, JSON sai,
  chi nhánh seed null, PUT giữ tọa độ/thời lượng slot.
- `test/features/admin_facility/domain/facility_rules_test.dart`: quy tắc
  giờ, BIN, số tài khoản, số điện thoại.
- `facility_blocs_test.dart` / `facility_screens_test.dart`: tạo/sửa, chặn
  giờ ngược, lỗi gói, thẻ chi nhánh, SnackBar chúc mừng, validation form.

Task: https://bro73.atlassian.net/browse/SCRUM-15
