# SCRUM-9 — SuperAdmin duyệt hồ sơ chủ sân

Feature: `lib/features/super_admin/` (data / domain / presentation theo
`lib/features/README.md`). Backend: SCRUM-8, auth-service cổng 8081, nhánh
`feature/Tuan-SCRUM-8-super-admin` của `fcourt-backend`.

## Luồng sử dụng

- `/super-admin/owners/pending` (`PendingOwnersScreen`): danh sách hồ sơ chủ
  sân chờ duyệt dạng Card (tên, email, SĐT, số giấy tờ pháp lý, ngày đăng ký).
  Kéo xuống để tải lại; nút Tải lại trên AppBar; lỗi hiển thị kèm Thử lại và
  vẫn giữ danh sách cũ.
- `/super-admin/owners/:ownerId` (`OwnerApprovalDetailScreen`): thông tin hồ
  sơ, ảnh "Giấy phép kinh doanh / CCCD" và "Ảnh sân". Chạm ảnh để mở toàn màn
  hình, phóng to bằng hai ngón (`InteractiveViewer`, tối đa 6x; ảnh tải qua
  `cached_network_image`).
- Duyệt: hộp thoại xác nhận, ghi chú không bắt buộc (≤ 500 ký tự).
- Từ chối: hộp thoại bắt buộc nhập lý do (1..500 ký tự, bỏ khoảng trắng hai
  đầu).
- Khi đang gửi: khóa hai nút, hiện thanh tiến trình, chặn nút Back. Thành
  công: quay về danh sách, hồ sơ bị xóa khỏi danh sách ngay (không chờ gọi
  lại API) và hiện SnackBar "Đã duyệt/Đã từ chối hồ sơ ...". Lỗi: SnackBar,
  giữ nguyên màn hình để thử lại.
- Hồ sơ không còn chờ duyệt (mở trực tiếp URL): hiện trạng thái, ẩn nút thao
  tác.

## Chạy thử

```powershell
flutter pub get
flutter run --dart-define-from-file=env/dev.json `
  --dart-define=AUTH_BASE_URL=http://10.0.2.2:8081 `
  --route /super-admin/owners/pending
```

`AUTH_BASE_URL` không bắt buộc; nếu bỏ trống, app dùng `API_BASE_URL` (ví dụ
khi đi qua gateway). Trên điện thoại thật dùng địa chỉ LAN của máy chạy
backend. Chưa có menu SuperAdmin nên mở màn hình bằng `--route` (hoặc
`context.go('/super-admin/owners/pending')`).

### Đưa token SUPER_ADMIN vào app (chưa có màn đăng nhập)

SCRUM-7 (đăng nhập Flutter) chưa có, nên app chưa tự lưu token. Mọi request
lấy Bearer token từ `TokenStorage` (`flutter_secure_storage`, khóa
`access_token` và `refresh_token`). Để thử trên máy dev, tạm thêm vào
`lib/main.dart` trước `runApp` và **không commit**:

```dart
await SecureTokenStorage().save(
  const AuthTokens(accessToken: '<JWT role SUPER_ADMIN>', refreshToken: '<refresh token>'),
);
```

JWT phải do auth-service ký (RS256, issuer `http://localhost:8081`, audience
`fcourt`, claim `roles` chứa `SUPER_ADMIN`), lấy từ API đăng nhập của
auth-service (SCRUM-6) bằng tài khoản SuperAdmin trong seed. Gỡ đoạn trên sau
khi thử; khi SCRUM-7 xong, màn đăng nhập sẽ ghi token qua cùng `TokenStorage`.

## API đã tích hợp (auth-service, chỉ SUPER_ADMIN)

| Thao tác | Request | Response |
| --- | --- | --- |
| Danh sách chờ | `GET /api/super-admin/court-admins/pending` | `CourtAdminResponse[]` |
| Chi tiết | `GET /api/super-admin/court-admins/{id}` | `CourtAdminResponse` |
| Duyệt | `PUT /api/super-admin/court-admins/{id}/approve`, body `{}` hoặc `{"reason": "..."}` | `CourtAdminResponse`, `status=ACTIVE` |
| Từ chối | `PUT /api/super-admin/court-admins/{id}/reject`, body `{"reason": "..."}` | `CourtAdminResponse`, `status=REJECTED` |

`CourtAdminResponse`: `{id, email, fullName, phone, role, status, createdAt,
documents: [{id, url, docType: LEGAL | COURT_IMAGE}]}` với `status` thuộc
`PENDING_APPROVAL | ACTIVE | REJECTED | LOCKED | INACTIVE`.

- Danh sách chỉ giữ hồ sơ `PENDING_APPROVAL`, kể cả khi backend trả lẫn trạng
  thái khác.
- Response duyệt/từ chối phải có đúng `id` và trạng thái mới; nếu không, app
  báo "Chưa xác minh được kết quả" thay vì coi là thành công.
- JSON sai contract (thiếu id/email, status hoặc docType lạ, URL ảnh không phải
  http/https) → "Dữ liệu hồ sơ từ máy chủ không hợp lệ".
- Lỗi theo RFC 7807 ProblemDetail: 401 → phiên hết hạn (sau khi
  `AuthInterceptor` thử refresh); 403 → không có quyền SuperAdmin; 404 → không
  tìm thấy hồ sơ; 409 → hồ sơ đã được xử lý, tải lại danh sách; 400 → dùng
  `detail` của server; còn lại theo `failureFromDio`.

## Phần chờ backend / task khác

| Nội dung | Hiện tại trên app | Cần |
| --- | --- | --- |
| Số CCCD | Ghi "Chưa có trong API, xem ảnh giấy tờ" | Cột/trường CCCD trong auth-service |
| Tên, mã số doanh nghiệp | Như trên | Trường thông tin doanh nghiệp |
| Phân biệt giấy phép KD và CCCD | Chung nhóm "Giấy phép kinh doanh / CCCD" (`docType=LEGAL`) | docType riêng cho từng loại giấy tờ |
| Đăng nhập SuperAdmin | Nạp token thủ công (mục trên) | SCRUM-7 |
| Menu/điều hướng theo role | Mở bằng route | Shell điều hướng sau đăng nhập |
| Phân trang | Tải toàn bộ danh sách chờ | Chỉ cần nếu backend thêm phân trang |

Database `auth_db` hiện không có trường CCCD hay thông tin doanh nghiệp; app
không hiển thị dữ liệu giả cho các trường này.

## Kiểm chứng

Ngày 31/10/2026, Flutter 3.47.7, Windows:

- `flutter pub get`: thành công, không đổi dependency hay lockfile.
- `flutter analyze`: không có issue.
- `flutter test`: 46 tests pass, gồm 33 test mới của SuperAdmin:
  - repository với `FakeAdapter`: đường dẫn, method, body (approve không gửi
    `reason` khi trống), lọc PENDING, parse giấy tờ, JSON sai contract, ánh xạ
    lỗi 400/401/403/404/409/500 và lỗi kết nối;
  - use case: bỏ khoảng trắng, chặn lý do rỗng/quá 500 ký tự;
  - cubit (`bloc_test`): tải, tải lại lỗi giữ danh sách, xóa hồ sơ, duyệt,
    từ chối lỗi 409;
  - widget: danh sách chỉ hiện hồ sơ chờ, kéo để tải lại, danh sách rỗng,
    duyệt xong hồ sơ biến mất và hiện SnackBar (qua go_router thật), từ chối
    bắt buộc lý do, lỗi 409 hiện SnackBar, mở ảnh giấy tờ có zoom.
- `dart format --set-exit-if-changed` trên các file của task: pass. Chạy cho
  toàn bộ `lib test` vẫn báo 6 file có sẵn từ commit khởi tạo (`app_theme`,
  `auth_interceptor`, `dio_client`, `token_storage`, `health_page`,
  `auth_interceptor_test`); task này không định dạng lại các file đó.
- `flutter build apk --debug --dart-define-from-file=env/dev.json`: build
  thành công `build/app/outputs/flutter-apk/app-debug.apk`.
- Chưa chạy trên emulator/thiết bị thật và chưa gọi auth-service thật (máy
  không có emulator/adb; SCRUM-8 đang làm song song). Contract lấy theo đặc tả
  SCRUM-8; cần kiểm tra lại khi backend merge.

Task: SCRUM-9. Phụ thuộc: SCRUM-8 (backend), SCRUM-7 (đăng nhập Flutter).
