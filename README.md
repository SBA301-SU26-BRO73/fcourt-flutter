# FCOURT Flutter

Ứng dụng Android của FCOURT. Viết bằng Flutter theo Clean Architecture, chia theo feature. Repo đã có sẵn thư viện cơ bản (gọi API, lưu token, điều hướng, state management) và một feature mẫu `health` để sao chép cấu trúc.

Feature Customer Discovery (SCRUM-21) mở tại trang chủ. Hướng dẫn API,
cấu hình discovery-service và các phần đang chờ backend ở
[`docs/SCRUM-21.md`](docs/SCRUM-21.md).

## Yêu cầu

- Flutter `3.47.7` (stable), đi kèm Dart `3.13.5`.
- Android Studio hoặc Android SDK và một emulator/thiết bị Android.
- Backend chạy ở máy local (xem repo `fcourt-backend`) hoặc trỏ tới server có sẵn.

## Chạy app

```bash
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```

Kiểm tra chất lượng trước khi tạo Pull Request:

```bash
flutter analyze
flutter test
```

### CI (GitHub Actions)

- `flutter analyze` coi cả `info` là lỗi, cả ở local lẫn CI (`--fatal-infos --fatal-warnings`). Chạy lại `flutter analyze` sau khi merge `dev` vào nhánh của bạn, vì CI kiểm tra bản merge với `dev`.
- Phiên bản Flutter ghim ở một chỗ: `.github/actions/setup-flutter/action.yml`. Đổi phiên bản thì sửa file đó và dòng Flutter ở mục yêu cầu.
- Script `.github/scripts/retry-on-network-error.sh` chỉ chạy lại lệnh khi log có dấu hiệu lỗi tải (HTTP 429/5xx, hash native asset sai, Gradle không tải được). Test fail và lỗi analyze không bao giờ bị chạy lại; đừng thêm retry quanh test.
- Required check giữ tên `analyze-and-test`, `android-build`, `signing-smoke`, `changes`. PR chỉ đổi tài liệu thì `analyze-and-test` được bỏ qua (tính là đạt).

## Xem giao diện trên trình duyệt

Ứng dụng có target web để rà giao diện và luồng với backend local:

```bash
flutter run -d chrome --web-hostname=127.0.0.1 --web-port=18100 --dart-define=API_BASE_URL=http://127.0.0.1:18080
```

Gateway cần cho phép origin `http://localhost:18100` hoặc `http://127.0.0.1:18100` đúng với URL trình duyệt đang mở. Các tính năng camera, lưu thư viện ảnh, push Firebase và offline native vẫn cần Android để kiểm chứng. Bản web không khởi tạo Firebase push.

Trang Cài đặt mở từ Home hoặc Tài khoản, cho chọn Theo hệ thống / Sáng / Tối và lưu trên thiết bị. Kết quả kiểm chứng giao diện, luồng đặt sân và các giới hạn môi trường: [docs/validation/MOBILE_UI_UX_2026-11-10.md](docs/validation/MOBILE_UI_UX_2026-11-10.md).

## Cấu hình môi trường

### Firebase Cloud Messaging (Android)

Ứng dụng Android dùng Firebase project **FCourt** (`chatappinno`), app **FCourt Android** (`com.bro73.fcourt`). Mỗi thành viên cần tải `google-services.json` từ Firebase Console: mở project FCourt, vào Project settings → General → Your apps → FCourt Android → Download `google-services.json`, rồi đặt tại `android/app/google-services.json`. File này đã được thêm vào `.gitignore`; không commit hoặc gửi file trong repository.

Cấu hình đọc lúc build qua `--dart-define-from-file`, không hard-code trong code.

| File | Dùng cho | `API_BASE_URL` |
|---|---|---|
| `env/dev.json` | máy local | `http://10.0.2.2:8080` (địa chỉ máy host nhìn từ Android emulator) |
| `env/prod.json` | production | `https://api.fcourt.example` (đổi khi có domain thật) |

- Chạy trên điện thoại thật: sửa `API_BASE_URL` thành IP LAN của máy chạy backend, ví dụ `http://192.168.1.10:8080`. Đừng commit thay đổi này.
- Bản debug cho phép `http` (cleartext). Bản release chỉ cho `https`.
- Không đưa secret vào `env/*.json`, vì file này được commit.
- Đăng nhập Google cần tạo OAuth Web client ID và Android client (package `com.bro73.fcourt`, SHA-1/SHA-256 của signing key) trong Google Cloud Console. Truyền Web client ID bằng `--dart-define=GOOGLE_WEB_CLIENT_ID=...` hoặc thêm khóa này vào file `--dart-define-from-file`. Cùng Web client ID phải được đặt vào `AUTH_GOOGLE_CLIENT_ID` của auth-service. Đây là client ID công khai, không phải client secret.

## Cấu trúc

```
lib/
├── main.dart                  # điểm vào, dựng AppDependencies rồi chạy app
├── app/                       # app.dart, router.dart, app_dependencies.dart, theme/
├── core/
│   ├── config/                # AppConfig (đọc dart-define)
│   ├── error/                 # Failure và failureFromDio
│   ├── network/               # Dio, AuthInterceptor (tự refresh token), ApiEndpoints
│   └── storage/               # TokenStorage (flutter_secure_storage)
└── features/
    └── <ten_feature>/         # data / domain / presentation
```

Quy tắc phụ thuộc: `presentation → domain ← data`. Chi tiết và cách thêm feature mới ở [`lib/features/README.md`](lib/features/README.md).

## Thư viện đã cài

| Thư viện | Dùng để |
|---|---|
| `flutter_bloc`, `equatable` | state management |
| `dio` | gọi API. `AuthInterceptor` gắn Bearer token và tự refresh khi gặp 401 |
| `go_router` | điều hướng |
| `flutter_secure_storage` | lưu access token và refresh token |
| `firebase_core`, `firebase_messaging` | khởi tạo Firebase Android, nhận FCM và lấy token thiết bị |
| `package_info_plus` | gửi phiên bản ứng dụng trong đăng ký thiết bị push |
| `freezed`, `json_serializable`, `build_runner` | sinh code model (chạy `dart run build_runner build`) |
| `cached_network_image`, `intl` | ảnh mạng, định dạng ngày giờ và tiền |
| `mobile_scanner` | quét QR. Quyền camera do owner feature quét QR khai báo khi dùng |
| `bloc_test`, `mocktail` | test bloc và mock |

## Gọi API

- Dùng `Dio` đã dựng sẵn trong `core/network/dio_client.dart`, đưa vào datasource qua constructor.
- Endpoint dùng chung đặt trong `core/network/api_endpoints.dart`.
- Request không cần token (đăng nhập, đăng ký) truyền `Options(extra: {AuthInterceptor.skipAuthKey: true})`.
- Datasource/repository bắt `DioException` và đổi thành `Failure` bằng `failureFromDio`, không để lỗi Dio lọt lên tầng giao diện.
- Refresh token gọi `POST /api/auth/refresh` với body `{"refreshToken": "..."}`. Nếu backend dùng đường dẫn khác, sửa `ApiEndpoints.authRefresh`.

## Quy ước làm việc

- Nhánh: `main` (production), `dev` (tích hợp), `feature/<tên>-<mô-tả>`, `fix/<tên>-<mô-tả>`.
- Commit theo dạng `type(scope): mô tả`, bắt buộc có scope là tên feature hoặc phần bị ảnh hưởng.
  - `type`: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`.
  - Ví dụ: `feat(booking): add booking history page`, `fix(auth): handle expired refresh token`, `chore(ci): bump flutter version`.
  - Không thêm dòng `Co-Authored-By` của AI vào commit.
- Mọi thay đổi vào `main` và `dev` đi qua Pull Request, ít nhất 1 review, CI `analyze-and-test` phải xanh. Không push trực tiếp.
- Không commit secret, token, file `.env`.

## Quản lý nhân viên (SCRUM-27)

Route `/admin/staff` dành cho ADMIN; mở từ “Quản lý nhân viên” ở màn hình
kiểm tra kết nối. Cần phiên đăng nhập do feature Auth cung cấp, lưu trong
`TokenStorage`; không nhập token hoặc hard-code tài khoản trong source.
API xác thực role/ownership phía máy chủ cho mọi thao tác.

Nếu không dùng gateway chung, cấu hình thêm `STAFF_BASE_URL` (staff: 8090)
và `FACILITY_BASE_URL` (facility: 8083) bằng dart-define; refresh token vẫn
đi qua `API_BASE_URL`. Không đặt token/secret trong JSON được commit.

Form sửa giữ nguyên email, chi nhánh và các ca làm đã có. Lỗi mạng/5xx giữ
nguyên dữ liệu và UUID để thử lại; đóng form khi kết quả chưa rõ cần đối soát
danh sách trước khi tạo lại. Mở khóa cần API bổ sung của staff và IAM:
`POST /api/admin/staff/{id}/reactivate`.

Xem [kế hoạch triển khai](FLUTTER_EXECUTION_PLAN.md) và
[kiểm chứng SCRUM-27](docs/validation/SCRUM-27.md).

## Chưa có trong khung

- Android flavors (dev/prod). Hiện tách môi trường bằng `env/*.json`.

## Check-in offline (SCRUM-116)

Android có snapshot SQLite theo nhân viên/chi nhánh/ngày và hàng đợi bền vững.
Đồng bộ đầu ca khi có mạng, chỉ nhận vé trong cửa sổ hợp lệ và cache dưới 12 giờ.
Kết quả offline là tạm thời; kiểm tra hàng đợi/xung đột sau khi kết nối lại.
Đổi tài khoản hoặc đăng xuất không cho phép dùng snapshot của phiên cũ.

Nếu mở lại app khi mất mạng, nhân viên có access token còn hạn, đúng vai trò
STAFF và snapshot hợp lệ của hôm nay được vào `/staff/offline`. Chế độ này
chỉ cho quét/nhập mã nhận sân; POS, lịch online và quản trị vẫn bị chặn.
Bấm “Kết nối lại để xác thực online” để khôi phục phiên đầy đủ qua server.
Token hết hạn, lỗi xác thực 401/403 hoặc cache sai ngày/cũ không được dùng
làm phiên offline.

Foreground đẩy hàng đợi mỗi 2 giây; reconnect/resume đẩy hàng đợi trước rồi
tải lại vé. Snapshot tự làm mới mỗi 5 phút; tải đầu ca thất bại tự thử lại
sau 30 giây. Các timer dừng khi app vào nền hoặc người dùng rời phiên nhân viên.
Đây là lịch thử đồng bộ, không phải cam kết server hoàn tất trong 3 giây.

Backend cần khóa ký permit và credential staff-to-booking riêng; tuyệt đối không
đưa secret này vào ứng dụng. Workmanager hỗ trợ gửi nền nhưng phụ thuộc Android;
không coi thời gian reconnect là cam kết khi chưa đo trên thiết bị.
Xem [kiểm chứng và cấu hình SCRUM-116](docs/validation/SCRUM-116.md).

## Android release

Cấu hình keystore, GitHub Secrets và kiểm chứng chữ ký APK/AAB: [docs/android-release.md](docs/android-release.md). Release thiếu signing config sẽ dừng; quy trình không dùng debug key để phát hành.
