import '../entities/calendar_slot.dart';
import '../entities/court_lock.dart';

/// Khóa slot, ngừng phục vụ và bao sân (facility-service SCRUM-49/111). Lỗi được
/// ném dưới dạng `Failure`; xung đột với booking/giữ chỗ là `LockConflictFailure`.
abstract class CourtLockRepository {
  Future<CourtLock> lockCourt(CourtLockRequest request);
  Future<CourtLockGroup> lockBranch(BranchLockRequest request);

  /// Khóa còn hiệu lực của chi nhánh (tùy chọn lọc theo sân và khoảng thời gian).
  Future<List<CourtLock>> getLocks(
    int branchId, {
    int? courtId,
    DateTime? from,
    DateTime? to,
  });

  Future<void> unlock(int lockId);
  Future<void> unlockGroup(String groupId);
}

/// Trạng thái từng ô của một sân theo ngày (discovery-service).
abstract class CourtCalendarRepository {
  Future<List<CalendarDay>> getDays(int courtId, List<DateTime> dates);
}
