import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../domain/staff.dart';

class HttpStaffRepository implements StaffRepository {
  HttpStaffRepository(this.staff, this.facility);
  final Dio staff;
  final Dio facility;

  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw failureFromDio(e);
    } on FormatException {
      throw const UnknownFailure('Dữ liệu máy chủ không hợp lệ');
    } on TypeError {
      throw const UnknownFailure('Dữ liệu máy chủ không hợp lệ');
    }
  }

  @override
  Future<List<StaffBranch>> branches() => _call(() async {
    final response = await facility.get<List<dynamic>>('/api/admin/branches');
    return (response.data ?? [])
        .cast<Map<String, dynamic>>()
        .where((r) => r['status'] == 'ACTIVE')
        .map((r) => StaffBranch(r['id'] as int, r['name'] as String))
        .toList();
  });

  @override
  Future<List<StaffMember>> list(int branchId, {int offset = 0}) => _call(
    () async {
      final response = await staff.get<List<dynamic>>(
        '/api/admin/staff',
        queryParameters: {'branchId': branchId, 'limit': 50, 'offset': offset},
      );
      return (response.data ?? [])
          .cast<Map<String, dynamic>>()
          .map(
            (r) => StaffMember(
              id: r['id'] as int,
              branchId: r['branchId'] as int,
              name: r['fullName'] as String? ?? 'Chưa có tên',
              email: r['email'] as String? ?? '',
              phone: r['phone'] as String? ?? '',
              active: r['active'] as bool,
              shifts: (r['shifts'] as List? ?? [])
                  .cast<Map<String, dynamic>>()
                  .map(
                    (s) => WorkShift(
                      s['dayOfWeek'] as int,
                      s['startTime'] as String,
                      s['endTime'] as String,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList();
    },
  );

  @override
  Future<void> save(StaffDraft draft, String key, {int? id}) => _call(() async {
    final body = <String, dynamic>{
      'fullName': draft.name.trim(),
      'phone': draft.phone.trim(),
      'shifts': draft.shifts
          .map(
            (s) => {
              'dayOfWeek': s.dayOfWeek,
              'startTime': s.startTime,
              'endTime': s.endTime,
            },
          )
          .toList(),
    };
    if (id == null) {
      body.addAll({
        'branchId': draft.branchId,
        'email': draft.email.trim().toLowerCase(),
        'password': draft.password,
      });
    }
    await staff.request<dynamic>(
      id == null ? '/api/admin/staff' : '/api/admin/staff/$id',
      data: body,
      options: Options(
        method: id == null ? 'POST' : 'PUT',
        headers: {'Idempotency-Key': key},
      ),
    );
  });

  @override
  Future<void> setActive(StaffMember member, bool active, String key) =>
      _call(() async {
        await staff.request<dynamic>(
          '/api/admin/staff/${member.id}${active ? '/reactivate' : ''}',
          options: Options(
            method: active ? 'POST' : 'DELETE',
            headers: {'Idempotency-Key': key},
          ),
        );
      });
}
