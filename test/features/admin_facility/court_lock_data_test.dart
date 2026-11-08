import 'package:dio/dio.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/admin_facility/data/datasources/facility_remote_data_source.dart';
import 'package:fcourt/features/admin_facility/data/models/court_lock_model.dart';
import 'package:fcourt/features/admin_facility/data/repositories/court_calendar_repository_impl.dart';
import 'package:fcourt/features/admin_facility/data/repositories/court_lock_repository_impl.dart';
import 'package:fcourt/features/admin_facility/data/repositories/facility_failures.dart';
import 'package:fcourt/features/admin_facility/domain/entities/calendar_slot.dart';
import 'package:fcourt/features/admin_facility/domain/entities/court_lock.dart';
import 'package:fcourt/src/features/customer_slots/domain/court_slot.dart';
import 'package:fcourt/src/features/customer_slots/domain/slot_repository.dart';
import 'package:fcourt/src/features/customer_slots/domain/slot_restriction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';

Map<String, dynamic> lockJson({
  int id = 40,
  String groupId = 'g-1',
  int courtId = 5,
  String type = 'PRIVATE_EVENT',
  String start = '2030-01-05T13:00:00',
  String end = '2030-01-05T18:00:00',
}) => {
  'id': id,
  'groupId': groupId,
  'branchId': 1,
  'courtId': courtId,
  'type': type,
  'startAt': start,
  'endAt': end,
  'reason': 'Giải đấu',
  'notes': 'Nội bộ',
  'publicReason': 'Giải đấu công ty',
  'contactName': 'Ban tổ chức',
  'contactPhone': '0901234567',
  'createdBy': 10,
  'createdAt': '2026-11-05T10:00:00+07:00',
};

({FakeAdapter adapter, CourtLockRepositoryImpl repo}) _repo(
  FakeHandler handler,
) {
  final adapter = FakeAdapter(handler);
  final dio = Dio(BaseOptions(baseUrl: 'http://facility'))
    ..httpClientAdapter = adapter;
  return (
    adapter: adapter,
    repo: CourtLockRepositoryImpl(FacilityRemoteDataSource(dio)),
  );
}

Map<String, dynamic> _problem(
  int status,
  String detail, {
  Map<String, dynamic> extra = const {},
}) => {
  'type': 'about:blank',
  'status': status,
  'detail': detail,
  'instance': '/api/admin/courts/lock-slots',
  ...extra,
};

const _details = LockDetails(
  type: LockType.privateEvent,
  reason: 'Giải đấu',
  publicReason: ' Giải đấu công ty ',
  contactPhone: '   ',
);

void main() {
  group('mergeSelection', () {
    final d1 = DateTime(2030, 1, 5);
    final d2 = DateTime(2030, 1, 6);
    int end(CellKey cell) =>
        cell.startMinute + 30 == 1440 ? 1440 : cell.startMinute + 30;

    test('gộp các ô liền kề thành một khoảng và tách khi có khoảng trống', () {
      final ranges = mergeSelection([
        CellKey(d1, 480),
        CellKey(d1, 510),
        CellKey(d1, 540),
        CellKey(d1, 600),
      ], end);
      expect(ranges, [
        LockRange(DateTime(2030, 1, 5, 8), DateTime(2030, 1, 5, 9, 30)),
        LockRange(DateTime(2030, 1, 5, 10), DateTime(2030, 1, 5, 10, 30)),
      ]);
    });

    test('không phụ thuộc thứ tự chọn và nối được qua nửa đêm', () {
      final ranges = mergeSelection([
        CellKey(d2, 0),
        CellKey(d1, 1410),
        CellKey(d1, 1380),
      ], end);
      expect(ranges, [
        LockRange(DateTime(2030, 1, 5, 23), DateTime(2030, 1, 6, 0, 30)),
      ]);
    });

    test('hai ngày không liền kề cho hai khoảng, rỗng cho không chọn gì', () {
      expect(
        mergeSelection([CellKey(d1, 480), CellKey(d2, 480)], end),
        hasLength(2),
      );
      expect(mergeSelection(const [], end), isEmpty);
    });

    test('wholeDays chạy từ 00:00 ngày đầu đến 00:00 sau ngày cuối', () {
      expect(
        wholeDays(DateTime(2030, 1, 5, 15), DateTime(2030, 1, 7)),
        LockRange(DateTime(2030, 1, 5), DateTime(2030, 1, 8)),
      );
      expect(
        wholeDays(DateTime(2030, 12, 31), DateTime(2030, 12, 31)).endAt,
        DateTime(2031, 1, 1),
      );
    });
  });

  test('CourtLock.overlaps dùng cửa sổ nửa mở', () {
    final lock = CourtLockModel.fromJson(lockJson());
    final t = DateTime(2030, 1, 5);
    expect(lock.overlaps(t.add(const Duration(hours: 12, minutes: 30)),
        t.add(const Duration(hours: 13))), isFalse);
    expect(lock.overlaps(t.add(const Duration(hours: 13)),
        t.add(const Duration(hours: 13, minutes: 30))), isTrue);
    expect(lock.overlaps(t.add(const Duration(hours: 17, minutes: 30)),
        t.add(const Duration(hours: 18))), isTrue);
    expect(lock.overlaps(t.add(const Duration(hours: 18)),
        t.add(const Duration(hours: 18, minutes: 30))), isFalse);
  });

  group('CourtLockModel', () {
    test('đọc LockResponse và từ chối loại khóa lạ', () {
      final lock = CourtLockModel.fromJson(lockJson());
      expect(lock.type, LockType.privateEvent);
      expect(lock.startAt, DateTime(2030, 1, 5, 13));
      expect(lock.publicReason, 'Giải đấu công ty');
      expect(
        () => CourtLockModel.fromJson(lockJson(type: 'MAINTENANCE')),
        throwsFormatException,
      );
      expect(
        () => CourtLockModel.fromJson(lockJson(start: '05/01/2030')),
        throwsFormatException,
      );
    });

    test('request chỉ gửi trường công khai khi có nội dung', () {
      final json = CourtLockModel.courtRequestToJson(
        CourtLockRequest(
          courtId: 5,
          startAt: DateTime(2030, 1, 5, 8, 30),
          endAt: DateTime(2030, 1, 6),
          details: _details,
        ),
      );
      expect(json, {
        'courtId': 5,
        'startAt': '2030-01-05T08:30:00',
        'endAt': '2030-01-06T00:00:00',
        'type': 'PRIVATE_EVENT',
        'reason': 'Giải đấu',
        'publicReason': 'Giải đấu công ty',
      });
    });

    test('request chi nhánh: allCourts loại trừ courtIds', () {
      final all = CourtLockModel.branchRequestToJson(
        BranchLockRequest(
          branchId: 1,
          allCourts: true,
          startAt: DateTime(2030, 1, 5, 13),
          endAt: DateTime(2030, 1, 5, 18),
          details: const LockDetails(type: LockType.outOfService, reason: 'x'),
        ),
      );
      expect(all['allCourts'], isTrue);
      expect(all.containsKey('courtIds'), isFalse);
      final some = CourtLockModel.branchRequestToJson(
        BranchLockRequest(
          branchId: 1,
          allCourts: false,
          courtIds: const [5, 6],
          startAt: DateTime(2030, 1, 5, 13),
          endAt: DateTime(2030, 1, 5, 18),
          details: const LockDetails(type: LockType.outOfService, reason: 'x'),
        ),
      );
      expect(some['courtIds'], [5, 6]);
      expect(some.containsKey('allCourts'), isFalse);
    });
  });

  group('CourtLockRepositoryImpl', () {
    test('lockCourt gọi POST lock-slots và đọc LockResponse', () async {
      final r = _repo((_) => jsonResponse(201, lockJson()));
      final lock = await r.repo.lockCourt(
        CourtLockRequest(
          courtId: 5,
          startAt: DateTime(2030, 1, 5, 13),
          endAt: DateTime(2030, 1, 5, 18),
          details: _details,
        ),
      );
      expect(lock.id, 40);
      final request = r.adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/admin/courts/lock-slots');
    });

    test('lockBranch đọc nhóm khóa của POST out-of-service', () async {
      final r = _repo(
        (_) => jsonResponse(201, {
          'groupId': 'g-9',
          'branchId': 1,
          'totalLocks': 2,
          'locks': [lockJson(courtId: 5), lockJson(id: 41, courtId: 6)],
        }),
      );
      final group = await r.repo.lockBranch(
        BranchLockRequest(
          branchId: 1,
          allCourts: true,
          startAt: DateTime(2030, 1, 5, 13),
          endAt: DateTime(2030, 1, 5, 18),
          details: _details,
        ),
      );
      expect(group.locks.map((l) => l.courtId), [5, 6]);
      expect(r.adapter.requests.single.path, '/api/admin/courts/out-of-service');
    });

    test('getLocks gửi branchId, courtId và khoảng thời gian cục bộ', () async {
      final r = _repo((_) => jsonResponse(200, [lockJson()]));
      final locks = await r.repo.getLocks(
        1,
        courtId: 5,
        from: DateTime(2030, 1, 5),
        to: DateTime(2030, 1, 12),
      );
      expect(locks, hasLength(1));
      expect(r.adapter.requests.single.queryParameters, {
        'branchId': 1,
        'courtId': 5,
        'from': '2030-01-05T00:00:00',
        'to': '2030-01-12T00:00:00',
      });
    });

    test('unlock và unlockGroup gọi đúng DELETE', () async {
      final r = _repo((_) => ResponseBody.fromString('', 204));
      await r.repo.unlock(40);
      await r.repo.unlockGroup('g-9');
      expect(r.adapter.requests.map((q) => '${q.method} ${q.path}'), [
        'DELETE /api/admin/courts/lock-slots/40',
        'DELETE /api/admin/courts/out-of-service/g-9',
      ]);
    });

    test('409 BOOKING_CONFLICT giữ danh sách slot xung đột', () async {
      final r = _repo(
        (_) => jsonResponse(
          409,
          _problem(
            409,
            'Cannot lock: 1 slot(s) already booked and 1 held by customers.',
            extra: {
              'code': 'BOOKING_CONFLICT',
              'conflicts': [
                {
                  'courtId': 5,
                  'date': '2030-01-05',
                  'slotId': 2,
                  'startTime': '13:00',
                  'endTime': '13:30',
                  'status': 'BOOKED',
                },
                {
                  'courtId': 5,
                  'date': '2030-01-05',
                  'slotId': 3,
                  'startTime': '13:30',
                  'endTime': '14:00',
                  'status': 'HOLD',
                },
              ],
            },
          ),
        ),
      );
      await expectLater(
        r.repo.lockCourt(
          CourtLockRequest(
            courtId: 5,
            startAt: DateTime(2030, 1, 5, 13),
            endAt: DateTime(2030, 1, 5, 18),
            details: _details,
          ),
        ),
        throwsA(
          isA<LockConflictFailure>()
              .having((f) => f.conflicts, 'conflicts', hasLength(2))
              .having((f) => f.conflicts.first.isBooked, 'booked', isTrue)
              .having((f) => f.statusCode, 'status', 409)
              .having((f) => f.message, 'message', contains('1 slot đã được đặt')),
        ),
      );
    });

    test('lỗi khác được dịch sang tiếng Việt', () async {
      for (final (status, detail, expected) in [
        (409, 'The window overlaps an existing lock on court(s) 5; cancel it first', 'trùng với một lịch khóa'),
        (503, 'Cannot verify existing bookings and holds right now; the lock was not created', 'Chưa kiểm tra được'),
        (400, 'The lock window is already in the past', 'đã qua'),
        (400, 'startAt and endAt must be on a 30-minute boundary (minutes 00 or 30)', 'bội số của 30 phút'),
        (400, 'A lock window can span at most 31 days', '31 ngày'),
        (404, 'Court not found', 'Không tìm thấy'),
      ]) {
        final r = _repo((_) => jsonResponse(status, _problem(status, detail)));
        await expectLater(
          r.repo.lockCourt(
            CourtLockRequest(
              courtId: 5,
              startAt: DateTime(2030, 1, 5, 13),
              endAt: DateTime(2030, 1, 5, 18),
              details: _details,
            ),
          ),
          throwsA(
            isA<ServerFailure>().having(
              (f) => f.message,
              'message',
              contains(expected),
            ),
          ),
          reason: detail,
        );
      }
    });
  });

  test('lịch sân dùng trạng thái của khách, nhận ra bao sân và khóa thường', () async {
    final slots = _FakeSlots({
      DateTime(2030, 1, 5): [
        const CourtSlot(
          id: 1,
          startMinute: 480,
          endMinute: 510,
          priceMinor: 1,
          status: SlotStatus.available,
        ),
        const CourtSlot(
          id: 2,
          startMinute: 510,
          endMinute: 540,
          priceMinor: 1,
          status: SlotStatus.outOfService,
          restriction: SlotRestriction(
            isPrivateEvent: true,
            publicReason: 'Giải đấu',
          ),
        ),
        const CourtSlot(
          id: 3,
          startMinute: 540,
          endMinute: 570,
          priceMinor: 1,
          status: SlotStatus.outOfService,
        ),
        const CourtSlot(
          id: 4,
          startMinute: 570,
          endMinute: 600,
          priceMinor: 1,
          status: SlotStatus.booked,
          // metadata chỉ có nghĩa với khóa; không biến slot đã đặt thành bao sân
          restriction: SlotRestriction(isPrivateEvent: true),
        ),
      ],
    });
    final days = await DiscoveryCourtCalendarRepository(slots)
        .getDays(5, [DateTime(2030, 1, 5, 14)]);
    final day = days.single;
    expect(day.date, DateTime(2030, 1, 5));
    expect(day.slots.map((s) => s.status), [
      CalendarSlotStatus.available,
      CalendarSlotStatus.locked,
      CalendarSlotStatus.locked,
      CalendarSlotStatus.booked,
    ]);
    expect(day.slots.map((s) => s.isPrivateEvent), [false, true, false, false]);
    expect(day.slots[1].publicReason, 'Giải đấu');
  });

  test('lịch chủ sân hết hạn ô trống đã qua theo giờ địa điểm', () async {
    final slots = _FakeSlots({
      DateTime(2030, 1, 5): [
        const CourtSlot(
          id: 1,
          startMinute: 540,
          endMinute: 570,
          priceMinor: 1,
          status: SlotStatus.available,
        ),
        const CourtSlot(
          id: 2,
          startMinute: 570,
          endMinute: 600,
          priceMinor: 1,
          status: SlotStatus.available,
        ),
      ],
    });
    final days = await DiscoveryCourtCalendarRepository(
      slots,
      now: () => DateTime.utc(2030, 1, 5, 2, 5), // 09:05 ICT
    ).getDays(5, [DateTime(2030, 1, 5)]);

    expect(days.single.slots.map((s) => s.status), [
      CalendarSlotStatus.expired,
      CalendarSlotStatus.available,
    ]);
  });
}

class _FakeSlots implements SlotRepository {
  _FakeSlots(this.byDate);

  final Map<DateTime, List<CourtSlot>> byDate;

  @override
  Future<List<CourtSlot>> getSlots(int courtId, DateTime date) async =>
      byDate[DateTime(date.year, date.month, date.day)] ?? const [];
}
