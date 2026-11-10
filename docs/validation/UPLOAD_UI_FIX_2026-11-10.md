# Upload ảnh và rà bố cục 4 vai trò — 2026-11-10

## Vì sao chưa upload được ảnh

1. **Môi trường local chưa có S3.** Auth, facility, discovery và payment đọc `STORAGE_S3_BUCKET`; để trống thì upload trả 503. Đã thêm MinIO (`s3`, cổng 9000/9001) vào `.fcourt-local/compose.json`, tạo bucket `fcourt-local` với policy public-read cho `avatars/`, `branches/`, `reviews/` (receipts, refund-proofs, owner-documents vẫn private, đọc qua presigned URL) và truyền biến `STORAGE_*`/`AWS_*` trong `.fcourt-local/start_services.py`.
2. **Flutter chỉ chấp nhận ảnh từ `res.cloudinary.com`.** Backend đã chuyển sang S3, nên biên lai (admin duyệt), lịch sử giao dịch, hoàn tiền và đơn admin đều coi URL S3 là dữ liệu lỗi. Thay bằng `lib/core/network/image_url.dart`: nhận HTTPS cổng mặc định hoặc HTTP trên loopback (MinIO local, giống `ReviewImagePolicy` của backend); vẫn từ chối userinfo, fragment, cổng lạ và HTTP từ xa.
3. **Ảnh đánh giá bắt buộc `https`**, nên URL `http://127.0.0.1:9000/...` do discovery trả về bị từ chối. Dùng cùng validator.
4. **Đăng ký chủ sân trên web bỏ mất tệp**: `MultipartFile.fromFile(path)` nhưng trình duyệt không có đường dẫn. `UploadDocument` mang thêm `bytes`; picker đọc nội dung khi không có path.

## Luồng và bố cục đã sửa

- Đơn `PENDING_PAYMENT` có nút **Thanh toán · Gửi biên lai** ở chi tiết đơn để mở lại VietQR/gửi biên lai. Nhãn thanh toán hiện "Chưa gửi biên lai" thay vì "Chờ duyệt" khi chưa gửi.
- Thanh tab kính không còn đè nội dung (`extendBody: false`); bỏ nút nổi "Kéo để xem thêm" luôn che thẻ sân.
- Mọi bottom sheet mở bằng root navigator, nên không còn nằm dưới thanh tab (ví dụ sheet duyệt biên lai).
- Sheet duyệt biên lai, màn gửi biên lai, chip giao dịch: thêm khoảng cách, nút không dính nhau.
- Lịch nhân viên: cách nút Hôm nay/Cả tuần, giờ `HH:mm`, khung đã qua hiện "Đã qua" thay vì "Đã đặt".
- Quản lý sân: thẻ sân rộng hết màn hình điện thoại (hàng icon không bị cắt).
- Hồ sơ cá nhân: nội dung bắt đầu từ trên thay vì nằm giữa màn hình.
- Thanh toán: ngày `dd/MM/yyyy`; thông báo realtime của màn chọn giờ không còn hiện "vừa có người giữ chỗ" trên màn thanh toán của chính người giữ.

## Kiểm chứng

- `flutter analyze`: không có lỗi. `flutter test`: 1030 test pass, sau đó 9/9 test lịch sử đặt sân (thêm 2 test nút thanh toán).
- Chrome 412×915, backend local thật, script và ảnh tại `.jira-audit/ui-upload-2026-11-10/`:
  - 41 màn của CUSTOMER/ADMIN/STAFF/SUPER_ADMIN: không có HTTP ≥ 400 và không có lỗi JS (`audit-all-412.json`, `shots/`).
  - ADMIN thêm ảnh chi nhánh: `POST /api/admin/branches/26/images` 201, ảnh tải về 200.
  - CUSTOMER đặt sân → rời checkout → mở lại từ lịch sử → chọn ảnh → `upload-receipt` 200.
  - ADMIN mở biên lai: ảnh presigned từ MinIO 200. Lịch sử giao dịch của khách hiển thị.
  - Đăng ký chủ sân kèm giấy tờ trên web: 201; SUPER_ADMIN xem được cả hai ảnh (200).
- Dữ liệu thử đã dọn: 2 biên lai bị từ chối (đơn CANCELLED, slot trả lại), 2 ảnh chi nhánh đã xóa, hồ sơ `ownerqa…` đã từ chối (`cleanup.json`).

## Chưa kiểm chứng

Camera/thư viện ảnh Android và upload ảnh đánh giá qua UI (cần một đơn COMPLETED). API ảnh đánh giá đã trả 201 với MinIO. Emulator Android không truy cập được `127.0.0.1:9000`; khi chạy app trên emulator cần đặt `STORAGE_PUBLIC_BASE_URL`/`STORAGE_S3_PRESIGN_ENDPOINT` về `http://10.0.2.2:9000`.
