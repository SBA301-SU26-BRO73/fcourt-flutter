import 'clock_time.dart';
import 'slot_template.dart';

/// Lý do khoảng giờ của mẫu không áp dụng được (trùng quy tắc backend).
enum SlotRangeIssue { endNotAfterStart, outsideBranchHours, notDivisible }

/// Bước chuẩn của mẫu khung giờ; backend hiện chỉ chấp nhận 30 phút.
const standardSlotMinutes = 30;

/// Một ngày có tối đa 24 * 60 / 30 = 48 slot 30 phút.
const maxSlotsPerDay = 24 * 60 ~/ standardSlotMinutes;

/// Sinh danh sách slot liên tiếp, không chồng lấn trong [start, end).
/// Trả về danh sách rỗng khi khoảng giờ không hợp lệ (xem [validateSlotRange]).
List<GeneratedSlot> generateSlotMatrix({
  required ClockTime start,
  required ClockTime end,
  required int price,
  int durationMinutes = standardSlotMinutes,
}) {
  if (durationMinutes <= 0) return const [];
  final range = end.inMinutes - start.inMinutes;
  if (range <= 0 || range % durationMinutes != 0) return const [];
  return [
    for (var m = start.inMinutes; m < end.inMinutes; m += durationMinutes)
      GeneratedSlot(
        startTime: ClockTime.fromMinutes(m),
        endTime: ClockTime.fromMinutes(m + durationMinutes),
        price: price,
      ),
  ];
}

/// Kiểm tra khoảng giờ trước khi xem trước/áp dụng.
SlotRangeIssue? validateSlotRange({
  required ClockTime start,
  required ClockTime end,
  ClockTime? branchOpen,
  ClockTime? branchClose,
  int durationMinutes = standardSlotMinutes,
}) {
  if (!start.isBefore(end)) return SlotRangeIssue.endNotAfterStart;
  if (branchOpen != null && start.isBefore(branchOpen)) {
    return SlotRangeIssue.outsideBranchHours;
  }
  if (branchClose != null && branchClose.isBefore(end)) {
    return SlotRangeIssue.outsideBranchHours;
  }
  if ((end.inMinutes - start.inMinutes) % durationMinutes != 0) {
    return SlotRangeIssue.notDivisible;
  }
  return null;
}

/// Giá mặc định mỗi slot = giá giờ * thời lượng / 60 (giống backend).
int defaultSlotPrice(
  int pricePerHour, {
  int durationMinutes = standardSlotMinutes,
}) => (pricePerHour * durationMinutes / 60).round();
