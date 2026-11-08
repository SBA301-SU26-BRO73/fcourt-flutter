import 'package:dio/dio.dart';

import '../../domain/entities/court_lock.dart';
import '../../domain/repositories/court_lock_repository.dart';
import '../datasources/facility_remote_data_source.dart';
import '../models/court_lock_model.dart';
import '../models/json_readers.dart';
import 'facility_failures.dart';

class CourtLockRepositoryImpl implements CourtLockRepository {
  const CourtLockRepositoryImpl(this._remote);

  final FacilityRemoteDataSource _remote;

  @override
  Future<CourtLock> lockCourt(CourtLockRequest request) => _write(
    () async => CourtLockModel.fromJson(
      readJsonObject(
        await _remote.lockCourt(CourtLockModel.courtRequestToJson(request)),
      ),
    ),
  );

  @override
  Future<CourtLockGroup> lockBranch(BranchLockRequest request) => _write(
    () async => CourtLockModel.groupFromJson(
      readJsonObject(
        await _remote.lockBranch(CourtLockModel.branchRequestToJson(request)),
      ),
    ),
  );

  @override
  Future<List<CourtLock>> getLocks(
    int branchId, {
    int? courtId,
    DateTime? from,
    DateTime? to,
  }) => facilityCall(() async {
    final body = await _remote.getLocks({
      'branchId': branchId,
      'courtId': ?courtId,
      if (from != null) 'from': CourtLockModel.formatDateTime(from),
      if (to != null) 'to': CourtLockModel.formatDateTime(to),
    });
    return readJsonList(body).map(CourtLockModel.fromJson).toList();
  });

  @override
  Future<void> unlock(int lockId) => facilityCall(() => _remote.unlock(lockId));

  @override
  Future<void> unlockGroup(String groupId) =>
      facilityCall(() => _remote.unlockGroup(groupId));

  /// Ghi khóa: 409 `BOOKING_CONFLICT` giữ lại danh sách slot xung đột để UI
  /// báo rõ chủ sân cần liên hệ khách nào; các lỗi khác đi qua [facilityCall].
  Future<T> _write<T>(Future<T> Function() call) => facilityCall(() async {
    try {
      return await call();
    } on DioException catch (e) {
      final data = e.response?.data;
      if (e.response?.statusCode == 409 &&
          data is Map<String, dynamic> &&
          data['code'] == 'BOOKING_CONFLICT') {
        throw LockConflictFailure.fromConflicts(
          CourtLockModel.conflictsFromJson(data['conflicts']),
        );
      }
      rethrow;
    }
  });
}
