# Features

Mỗi tính năng là một thư mục riêng, chia ba tầng. Feature `health` là mẫu, sao chép cấu trúc này khi thêm feature mới.

```
features/<ten_feature>/
├── data/
│   ├── datasources/     # gọi API (Dio)
│   ├── models/          # DTO, fromJson, chuyển sang entity
│   └── repositories/    # triển khai repository, đổi DioException thành Failure
├── domain/
│   ├── entities/        # đối tượng nghiệp vụ thuần Dart
│   ├── repositories/    # interface repository
│   └── usecases/        # mỗi use case một việc
└── presentation/
    ├── bloc/            # event, state, bloc
    └── pages/           # màn hình và widget
```

Quy tắc phụ thuộc: `presentation → domain ← data`. Tầng `domain` không import Flutter, Dio hay thư viện bên ngoài.

Thêm feature mới:

1. Tạo thư mục theo cấu trúc trên.
2. Tạo repository thật trong `app/app_dependencies.dart` và thêm vào `AppDependencies`.
3. Thêm route trong `app/router.dart`.
4. Viết test cho bloc và use case trong `test/features/<ten_feature>/`.
