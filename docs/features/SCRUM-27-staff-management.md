# SCRUM-27: staff management (Flutter)


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

Xem [kế hoạch triển khai](../planning/FLUTTER_EXECUTION_PLAN.md) và
[kiểm chứng SCRUM-27](../validation/SCRUM-27.md).

