import '../entities/calendar_slot.dart';
import '../entities/court_lock.dart';
import '../repositories/court_lock_repository.dart';

class LockCourt {
  const LockCourt(this._repository);

  final CourtLockRepository _repository;

  Future<CourtLock> call(CourtLockRequest request) =>
      _repository.lockCourt(request);
}

class LockBranch {
  const LockBranch(this._repository);

  final CourtLockRepository _repository;

  Future<CourtLockGroup> call(BranchLockRequest request) =>
      _repository.lockBranch(request);
}

class GetCourtLocks {
  const GetCourtLocks(this._repository);

  final CourtLockRepository _repository;

  Future<List<CourtLock>> call(
    int branchId, {
    int? courtId,
    DateTime? from,
    DateTime? to,
  }) => _repository.getLocks(branchId, courtId: courtId, from: from, to: to);
}

class UnlockCourt {
  const UnlockCourt(this._repository);

  final CourtLockRepository _repository;

  Future<void> call(int lockId) => _repository.unlock(lockId);
}

class UnlockGroup {
  const UnlockGroup(this._repository);

  final CourtLockRepository _repository;

  Future<void> call(String groupId) => _repository.unlockGroup(groupId);
}

class GetCalendarDays {
  const GetCalendarDays(this._repository);

  final CourtCalendarRepository _repository;

  Future<List<CalendarDay>> call(int courtId, List<DateTime> dates) =>
      _repository.getDays(courtId, dates);
}
