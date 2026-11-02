# SCRUM-23 — Chọn khung giờ 30 phút

Feature: `lib/src/features/customer_slots/`, theo Clean Architecture.
Nguồn giao diện React: `src/pages/slot-booking/slot-booking-page.tsx`,
`components/court-availability-grid.tsx` và `components/booking-panel.tsx`
trong frontend tham chiếu người thực hiện cung cấp.

## Chức năng

- Thanh 8 ngày và date picker; lưới ô lớn cho màn hình cảm ứng.
- AVAILABLE xanh lá, BOOKED đỏ, HOLD cam, OUT_OF_SERVICE tím xám;
  EXPIRED và trạng thái không nhận diện bị khóa.
- Chọn/bỏ chọn nhiều ô, bao gồm các ô liên tiếp; chỉ thao tác hợp lệ mới
  gửi `HapticFeedback.selectionClick`. Rung vật lý cần kiểm tra trên Android.
- BottomBar hiển thị số slot, thời lượng và tổng tạm tính. Giá lưu bằng đơn
  vị 0,01 đồng để cộng chính xác; không tự áp phụ thu cao điểm của React.
- Đổi ngày xóa lựa chọn; bỏ response cũ khi tải bất đồng bộ. Tải lại giữ
  lựa chọn còn trống và cập nhật giá; lỗi tải lại xóa lựa chọn. Kiểm tra
  slot đã bắt đầu mỗi 15 giây theo giờ Việt Nam và trước thao tác chọn.
- Tải lại thủ công/kéo xuống và khi ứng dụng quay về foreground.

## API và điều hướng

API SCRUM-22: `GET /api/public/courts/{courtId}/slots?date=YYYY-MM-DD`,
response mảng trực tiếp, không JWT. Dùng `DISCOVERY_BASE_URL` như Discovery.
Không tạo slot ngoài lịch, không mặc định trạng thái lạ thành AVAILABLE.

Route: `/courts/:courtId/slots?date=2030-01-01&courtName=...&branchName=...`.
Court ID phải là ID thật; tên là tham số tùy chọn. Ngày không hợp lệ dùng
ngày hiện tại. Branch API chưa có danh sách court IDs nên chưa nối tự động
từ BranchDetail; không suy đoán court ID từ số lượng sân.

`SlotPickerScreen.onContinue` nhận `SlotSelection` có court ID, ngày và
slot ID/start/end/priceMinor. Chưa có callback thì nút Xem lựa chọn chỉ mở
tóm tắt tạm tính, không tạo booking hoặc giữ chỗ. SCRUM-25 chưa merge:
adapter tương lai cần ánh xạ sang BookingSelection/BookingSummaryArguments;
không chuyển giá lẻ sang `priceVnd` nguyên bằng cách làm tròn âm thầm.

Backend thật phụ thuộc upstream facility/booking của SCRUM-22. Fixtures
`discovery-service/examples/slot_sources.py` là dữ liệu kiểm thử local,
không phải backend production; không nhúng fixture vào Flutter.

## Kiểm chứng và review

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

Chưa xác nhận build APK hoặc chạy emulator do máy chưa có Android SDK.
Unit/widget tests không thay thế kiểm tra rung trên thiết bị thật.

Kiểm chứng ngày 28/10/2026: Flutter 3.47.7/Dart 3.13.5, analyzer sạch;
toàn bộ 34 tests pass (12 tests Slot mới). Tests gồm contract API, trạng
thái bị khóa, haptic channel, tính tiền, đổi ngày/race, refresh, hết giờ,
callback và layout 320 px với text scale 1,6. Không claim HTTP smoke với
backend thật hoặc chạy Android trong lần bàn giao này.

Task: https://bro73.atlassian.net/browse/SCRUM-23

Request Review: https://bro73.atlassian.net/browse/SCRUM-146

Nhánh `feature/Dang-customer-slot-picker` kế thừa Discovery tại `796d17a`.
PR #6 của Discovery chưa merge nên PR Slot tạm target
`feature/Dang-customer-discovery` để diff chỉ chứa SCRUM-23. Không merge
vào feature cha. Sau khi PR #6 được người có trách nhiệm merge, rebase
riêng các commit Slot lên dev và retarget PR; nếu Discovery được squash,
không chỉ đổi base vì có thể kéo lại các commit Discovery cũ.

Các commit tách theo data/domain, Cubit, UI/navigation, tests, CI và tài liệu.
CI nhận cả PR có base feature để kiểm chứng nhánh xếp chồng trước khi về dev.
Diff vượt gợi ý ~300 dòng do màn hình mới cùng tests; review theo từng commit.
Reviewer Jira: Từ Phúc Nguyên. Reviewer GitHub: `donan2k5`.
