import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../data/repositories/facility_failures.dart';
import '../../domain/entities/branch.dart';
import '../../domain/entities/court.dart';
import '../../domain/entities/court_lock.dart';
import '../../domain/usecases/branch_usecases.dart';
import '../../domain/usecases/court_usecases.dart';
import '../../domain/usecases/lock_usecases.dart';

part 'out_of_service_event.dart';
part 'out_of_service_state.dart';

/// SCRUM-112: bao sân / khóa bảo trì cho cả chi nhánh hoặc một số sân bằng một
/// lệnh (`POST /api/admin/courts/out-of-service`), xem và hủy các lịch khóa.
class OutOfServiceBloc extends Bloc<OutOfServiceEvent, OutOfServiceState> {
  OutOfServiceBloc({
    required this.branchId,
    required this._getBranch,
    required this._getCourts,
    required this._getLocks,
    required this._lockBranch,
    required this._unlockCourt,
    required this._unlockGroup,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const OutOfServiceState()) {
    on<OutOfServiceStarted>(_onStarted);
    on<OutOfServiceRefreshed>((_, emit) => _reload(emit));
    on<OutOfServiceSubmitted>(_onSubmitted);
    on<OutOfServiceUnlockRequested>(_onUnlock);
  }

  final int branchId;
  final GetBranch _getBranch;
  final GetCourts _getCourts;
  final GetCourtLocks _getLocks;
  final LockBranch _lockBranch;
  final UnlockCourt _unlockCourt;
  final UnlockGroup _unlockGroup;
  final DateTime Function() _now;

  Future<void> _onStarted(
    OutOfServiceStarted event,
    Emitter<OutOfServiceState> emit,
  ) async {
    emit(const OutOfServiceState());
    try {
      final branch = await _getBranch(branchId);
      final courts = await _getCourts(branchId);
      final groups = await _fetchGroups();
      emit(
        OutOfServiceState(
          status: OutOfServiceStatus.ready,
          branch: branch,
          courts: courts,
          groups: groups,
        ),
      );
    } on Failure catch (failure) {
      emit(
        OutOfServiceState(
          status: OutOfServiceStatus.failure,
          message: failure.message,
        ),
      );
    }
  }

  /// Khóa còn hiệu lực từ hôm nay trở đi, gộp theo lệnh (`groupId`).
  Future<List<LockGroupView>> _fetchGroups() async {
    final today = _now();
    final locks = await _getLocks(
      branchId,
      from: DateTime(today.year, today.month, today.day),
    );
    return groupLocks(locks);
  }

  Future<void> _reload(Emitter<OutOfServiceState> emit) async {
    try {
      emit(state.copyWith(groups: await _fetchGroups()));
    } on Failure catch (failure) {
      emit(state.copyWith(notice: OutOfServiceNotice(failure.message, isError: true)));
    }
  }

  Future<void> _onSubmitted(
    OutOfServiceSubmitted event,
    Emitter<OutOfServiceState> emit,
  ) async {
    if (state.submitting) return;
    emit(state.copyWith(submitting: true, clearConflicts: true));
    try {
      final group = await _lockBranch(event.request);
      emit(
        state.copyWith(
          submitting: false,
          notice: OutOfServiceNotice(
            'Đã khóa ${group.locks.length} sân. Lịch sân được cập nhật ngay.',
            saved: true,
          ),
        ),
      );
      await _reload(emit);
    } on LockConflictFailure catch (failure) {
      emit(
        state.copyWith(
          submitting: false,
          conflicts: failure.conflicts,
          notice: OutOfServiceNotice(failure.message, isError: true),
        ),
      );
    } on Failure catch (failure) {
      emit(
        state.copyWith(
          submitting: false,
          notice: OutOfServiceNotice(failure.message, isError: true),
        ),
      );
    }
  }

  Future<void> _onUnlock(
    OutOfServiceUnlockRequested event,
    Emitter<OutOfServiceState> emit,
  ) async {
    if (state.submitting) return;
    emit(state.copyWith(submitting: true));
    OutOfServiceNotice notice;
    try {
      final groupId = event.groupId;
      if (groupId != null) {
        await _unlockGroup(groupId);
      } else {
        await _unlockCourt(event.lockId!);
      }
      notice = OutOfServiceNotice('Đã mở khóa');
    } on Failure catch (failure) {
      notice = OutOfServiceNotice(failure.message, isError: true);
    }
    emit(state.copyWith(submitting: false, notice: notice));
    await _reload(emit);
  }
}

/// Gộp khóa theo lệnh tạo (`groupId`), sắp theo giờ bắt đầu.
List<LockGroupView> groupLocks(List<CourtLock> locks) {
  final byGroup = <String, List<CourtLock>>{};
  for (final lock in locks) {
    byGroup.putIfAbsent(lock.groupId, () => []).add(lock);
  }
  final groups = [
    for (final entry in byGroup.entries)
      LockGroupView(
        groupId: entry.key,
        locks: [...entry.value]..sort((a, b) => a.courtId.compareTo(b.courtId)),
      ),
  ]..sort((a, b) => a.startAt.compareTo(b.startAt));
  return groups;
}
