# SCRUM-116: offline check-in (Flutter)


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
Xem [kiểm chứng và cấu hình SCRUM-116](../validation/SCRUM-116.md).

