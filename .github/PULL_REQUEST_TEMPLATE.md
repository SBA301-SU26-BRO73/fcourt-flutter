## Mô tả

<!-- Thay đổi gì, vì sao. Liên kết task Jira, ví dụ SCRUM-123 -->

## Feature bị ảnh hưởng

<!-- Ví dụ: auth, booking, core/network -->

## Loại thay đổi

- [ ] Tính năng mới
- [ ] Sửa lỗi
- [ ] Thay đổi `core/` hoặc `app/` (ảnh hưởng nhiều feature)
- [ ] Refactor / tài liệu / chore

## Cách test

<!-- Các bước đã chạy để kiểm tra, kèm ảnh chụp màn hình nếu có thay đổi giao diện -->

## Checklist

- [ ] Đúng cấu trúc `data / domain / presentation` trong `lib/features/<feature>/`
- [ ] Đã chạy `flutter analyze` và `flutter test`, không có lỗi
- [ ] Đã viết test cho bloc hoặc use case mới
- [ ] Không commit secret, token, file `.env`
- [ ] Đã cập nhật README nếu thay đổi cách chạy hoặc cấu hình
