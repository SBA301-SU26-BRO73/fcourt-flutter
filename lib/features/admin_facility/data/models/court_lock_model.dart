import '../../domain/entities/court_lock.dart';
import 'json_readers.dart';

/// Chuyển JSON `LockResponse` của facility-service sang entity và ngược lại.
abstract final class CourtLockModel {
  /// `yyyy-MM-ddTHH:mm:ss` theo giờ địa phương của sân, không múi giờ.
  static String formatDateTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-${two(value.month)}-'
        '${two(value.day)}T${two(value.hour)}:${two(value.minute)}:'
        '${two(value.second)}';
  }

  static DateTime parseDateTime(Map<String, dynamic> json, String key) {
    final raw = json.readString(key);
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?$',
    ).firstMatch(raw);
    if (match == null) {
      throw FormatException('Trường "$key" phải có dạng yyyy-MM-ddTHH:mm:ss', raw);
    }
    int g(int i) => int.parse(match.group(i) ?? '0');
    return DateTime(g(1), g(2), g(3), g(4), g(5), g(6));
  }

  static CourtLock fromJson(Map<String, dynamic> json) {
    final type = LockType.fromApi(json['type']);
    if (type == null) throw FormatException('Loại khóa không hợp lệ', json['type']);
    return CourtLock(
      id: json.readInt('id'),
      groupId: json.readString('groupId'),
      branchId: json.readInt('branchId'),
      courtId: json.readInt('courtId'),
      type: type,
      startAt: parseDateTime(json, 'startAt'),
      endAt: parseDateTime(json, 'endAt'),
      reason: json.readString('reason'),
      notes: json.readStringOrNull('notes'),
      publicReason: json.readStringOrNull('publicReason'),
      contactName: json.readStringOrNull('contactName'),
      contactPhone: json.readStringOrNull('contactPhone'),
    );
  }

  static CourtLockGroup groupFromJson(Map<String, dynamic> json) {
    final locks = readJsonList(json['locks']).map(fromJson).toList();
    return CourtLockGroup(groupId: json.readString('groupId'), locks: locks);
  }

  static Map<String, dynamic> _details(LockDetails d) => {
    'type': d.type.apiValue,
    'reason': d.reason,
    if (_filled(d.notes)) 'notes': d.notes!.trim(),
    if (_filled(d.publicReason)) 'publicReason': d.publicReason!.trim(),
    if (_filled(d.contactName)) 'contactName': d.contactName!.trim(),
    if (_filled(d.contactPhone)) 'contactPhone': d.contactPhone!.trim(),
  };

  static bool _filled(String? value) => value != null && value.trim().isNotEmpty;

  static Map<String, dynamic> courtRequestToJson(CourtLockRequest r) => {
    'courtId': r.courtId,
    'startAt': formatDateTime(r.startAt),
    'endAt': formatDateTime(r.endAt),
    ..._details(r.details),
  };

  static Map<String, dynamic> branchRequestToJson(BranchLockRequest r) => {
    'branchId': r.branchId,
    if (r.allCourts) 'allCourts': true else 'courtIds': r.courtIds,
    'startAt': formatDateTime(r.startAt),
    'endAt': formatDateTime(r.endAt),
    ..._details(r.details),
  };

  static List<LockConflict> conflictsFromJson(Object? raw) {
    if (raw is! List) return const [];
    final result = <LockConflict>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      result.add(
        LockConflict(
          courtId: item.readInt('courtId'),
          date: item.readString('date'),
          startTime: item.readString('startTime'),
          endTime: item.readString('endTime'),
          status: item.readString('status'),
        ),
      );
    }
    return result;
  }
}
