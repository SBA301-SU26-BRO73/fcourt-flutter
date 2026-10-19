# FCOURT Flutter

Ứng dụng Android của FCOURT. Viết bằng Flutter theo Clean Architecture, chia theo feature. Repo đã có sẵn thư viện cơ bản (gọi API, lưu token, điều hướng, state management) và một feature mẫu `health` để sao chép cấu trúc.

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

## Cấu hình môi trường

Cấu hình đọc lúc build qua `--dart-define-from-file`, không hard-code trong code.

| File | Dùng cho | `API_BASE_URL` |
|---|---|---|
| `env/dev.json` | máy local | `http://10.0.2.2:8080` (địa chỉ máy host nhìn từ Android emulator) |
| `env/prod.json` | production | `https://api.fcourt.example` (đổi khi có domain thật) |

- Chạy trên điện thoại thật: sửa `API_BASE_URL` thành IP LAN của máy chạy backend, ví dụ `http://192.168.1.10:8080`. Đừng commit thay đổi này.
- Bản debug cho phép `http` (cleartext). Bản release chỉ cho `https`.
- Không đưa secret vào `env/*.json`, vì file này được commit.

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

## Chưa có trong khung

- Android flavors (dev/prod). Hiện tách môi trường bằng `env/*.json`.
- Firebase/FCM, Google Maps, đăng nhập Google. Owner feature tương ứng tự thêm khi cần.
