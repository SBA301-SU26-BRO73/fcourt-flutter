import 'package:bloc_test/bloc_test.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/admin_facility/data/repositories/facility_failures.dart';
import 'package:fcourt/features/admin_facility/domain/entities/calendar_slot.dart';
import 'package:fcourt/features/admin_facility/domain/entities/court_lock.dart';
import 'package:fcourt/features/admin_facility/domain/repositories/court_lock_repository.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/branch_usecases.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/court_usecases.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/lock_usecases.dart';
import 'package:fcourt/features/admin_facility/presentation/bloc/court_calendar_bloc.dart';
import 'package:fcourt/features/admin_facility/presentation/bloc/out_of_service_bloc.dart';
import 'package:fcourt/features/admin_facility/presentation/pages/court_calendar_screen.dart';
import 'package:fcourt/features/admin_facility/presentation/pages/out_of_service_management_screen.dart';
import 'package:fcourt/features/admin_facility/domain/entities/clock_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fixtures.dart';
import '../mocks.dart';

class MockLockRepository extends Mock implements CourtLockRepository {}

class MockCalendarRepository extends Mock implements CourtCalendarRepository {}

final _monday = DateTime(2030, 1, 7);

CalendarSlot _slot(int start, CalendarSlotStatus status,
        {bool event = false}) =>
    CalendarSlot(
      startMinute: start,
      endMinute: start + 30,
      status: status,
      isPrivateEvent: event,
    );

List<CalendarDay> _week() => [
  for (var i = 0; i < 7; i++)
    CalendarDay(
      date: DateTime(2030, 1, 7 + i),
      slots: [
        _slot(480, CalendarSlotStatus.available),
        _slot(510, CalendarSlotStatus.available),
        _slot(540, CalendarSlotStatus.available),
        _slot(
          570,
          i == 0 ? CalendarSlotStatus.locked : CalendarSlotStatus.available,
          event: true,
        ),
        _slot(600, CalendarSlotStatus.booked),
      ],
    ),
];

CourtLock _lock({
  int id = 40,
  String group = 'g-1',
  int courtId = 5,
  LockType type = LockType.privateEvent,
  DateTime? start,
  DateTime? end,
}) => CourtLock(
  id: id,
  groupId: group,
  branchId: 1,
  courtId: courtId,
  type: type,
  startAt: start ?? DateTime(2030, 1, 7, 9, 30),
  endAt: end ?? DateTime(2030, 1, 7, 10),
  reason: 'Giải đấu',
  notes: 'Cọc tiền mặt',
  publicReason: 'Giải đấu công ty',
  contactName: 'Ban tổ chức',
  contactPhone: '0901234567',
);

const _details = LockDetails(type: LockType.outOfService, reason: 'Sửa sàn');

void main() {
  late MockLockRepository locks;
  late MockCalendarRepository calendar;
  late MockCourtRepository courts;
  late MockBranchRepository branches;

  setUpAll(() {
    registerFacilityFallbacks();
    registerFallbackValue(
      CourtLockRequest(
        courtId: 5,
        startAt: _monday,
        endAt: _monday,
        details: _details,
      ),
    );
    registerFallbackValue(
      BranchLockRequest(
        branchId: 1,
        allCourts: true,
        startAt: _monday,
        endAt: _monday,
        details: _details,
      ),
    );
    registerFallbackValue(_monday);
  });

  setUp(() {
    locks = MockLockRepository();
    calendar = MockCalendarRepository();
    courts = MockCourtRepository();
    branches = MockBranchRepository();
    when(() => courts.getCourt(5)).thenAnswer((_) async => sampleCourt());
    when(() => courts.getCourts(1)).thenAnswer(
      (_) async => [sampleCourt(id: 5), sampleCourt(id: 6)],
    );
    when(() => branches.getBranch(1)).thenAnswer((_) async => sampleBranch());
    when(() => calendar.getDays(5, any())).thenAnswer((_) async => _week());
    when(
      () => locks.getLocks(
        1,
        courtId: any(named: 'courtId'),
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => [_lock()]);
  });

  CourtCalendarBloc calendarBloc() => CourtCalendarBloc(
    courtId: 5,
    getCourt: GetCourt(courts),
    getDays: GetCalendarDays(calendar),
    getLocks: GetCourtLocks(locks),
    lockCourt: LockCourt(locks),
    unlockCourt: UnlockCourt(locks),
    today: () => DateTime(2030, 1, 9, 15),
  );

  OutOfServiceBloc oosBloc() => OutOfServiceBloc(
    branchId: 1,
    getBranch: GetBranch(branches),
    getCourts: GetCourts(courts),
    getLocks: GetCourtLocks(locks),
    lockBranch: LockBranch(locks),
    unlockCourt: UnlockCourt(locks),
    unlockGroup: UnlockGroup(locks),
    now: () => DateTime(2030, 1, 7, 8),
  );

  group('CourtCalendarBloc', () {
    test('tải tuần Thứ 2 - Chủ nhật chứa ngày đang xem cùng khóa của sân', () async {
      final bloc = calendarBloc()..add(const CalendarStarted());
      await bloc.stream.firstWhere((s) => s.status == CalendarStatus.ready);
      expect(bloc.state.visibleDates.first, _monday);
      expect(bloc.state.visibleDates.last, DateTime(2030, 1, 13));
      expect(bloc.state.locks.single.id, 40);
      verify(
        () => locks.getLocks(
          1,
          courtId: 5,
          from: _monday,
          to: DateTime(2030, 1, 14),
        ),
      ).called(1);
      await bloc.close();
    });

    test('chỉ chọn được ô trống; ô đã đặt hoặc đã khóa bị bỏ qua', () async {
      final bloc = calendarBloc()..add(const CalendarStarted());
      await bloc.stream.firstWhere((s) => s.status == CalendarStatus.ready);
      bloc
        ..add(CalendarCellToggled(CellKey(_monday, 480)))
        ..add(CalendarCellToggled(CellKey(_monday, 570))) // khóa
        ..add(CalendarCellToggled(CellKey(_monday, 600))) // đã đặt
        ..add(CalendarCellToggled(CellKey(DateTime(2030, 1, 8), 570)));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.selected, {
        CellKey(_monday, 480),
        CellKey(DateTime(2030, 1, 8), 570),
      });
      bloc.add(CalendarCellToggled(CellKey(_monday, 480)));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.selected, {CellKey(DateTime(2030, 1, 8), 570)});
      await bloc.close();
    });

    test('khóa các ô gộp thành khoảng liên tục và tải lại lịch', () async {
      when(() => locks.lockCourt(any())).thenAnswer((_) async => _lock());
      final bloc = calendarBloc()..add(const CalendarStarted());
      await bloc.stream.firstWhere((s) => s.status == CalendarStatus.ready);
      for (final minute in [480, 510, 540]) {
        bloc.add(CalendarCellToggled(CellKey(_monday, minute)));
      }
      bloc.add(CalendarCellToggled(CellKey(DateTime(2030, 1, 8), 480)));
      bloc.add(const CalendarLockSubmitted(_details));
      final saved = await bloc.stream
          .firstWhere((s) => s.notice != null && !s.submitting);
      final requests = verify(() => locks.lockCourt(captureAny())).captured
          .cast<CourtLockRequest>();
      expect(
        requests.map((r) => (r.startAt, r.endAt)),
        [
          (DateTime(2030, 1, 7, 8), DateTime(2030, 1, 7, 9, 30)),
          (DateTime(2030, 1, 8, 8), DateTime(2030, 1, 8, 8, 30)),
        ],
      );
      expect(requests.first.details, _details);
      expect(saved.notice!.isError, isFalse);
      await bloc.stream.firstWhere((s) => s.status == CalendarStatus.ready);
      expect(bloc.state.selected, isEmpty);
      verify(() => calendar.getDays(5, any())).called(2);
      await bloc.close();
    });

    test('xung đột booking dừng lại, báo số khoảng đã khóa và không giả vờ thành công', () async {
      var calls = 0;
      when(() => locks.lockCourt(any())).thenAnswer((_) async {
        if (++calls == 2) {
          throw LockConflictFailure.fromConflicts(const [
            LockConflict(
              courtId: 5,
              date: '2030-01-08',
              startTime: '08:00',
              endTime: '08:30',
              status: 'BOOKED',
            ),
          ]);
        }
        return _lock();
      });
      final bloc = calendarBloc()..add(const CalendarStarted());
      await bloc.stream.firstWhere((s) => s.status == CalendarStatus.ready);
      bloc
        ..add(CalendarCellToggled(CellKey(_monday, 480)))
        ..add(CalendarCellToggled(CellKey(DateTime(2030, 1, 8), 480)))
        ..add(const CalendarLockSubmitted(_details));
      final failed = await bloc.stream
          .firstWhere((s) => s.notice != null && !s.submitting);
      expect(failed.notice!.isError, isTrue);
      expect(failed.notice!.message, contains('1 slot đã được đặt'));
      expect(failed.notice!.message, contains('đã khóa 1/2 khoảng'));
      await bloc.close();
    });

    test('mở khóa gọi DELETE rồi tải lại; lỗi được báo', () async {
      when(() => locks.unlock(40)).thenAnswer((_) async {});
      final bloc = calendarBloc()..add(const CalendarStarted());
      await bloc.stream.firstWhere((s) => s.status == CalendarStatus.ready);
      bloc.add(const CalendarUnlockRequested(40));
      final done = await bloc.stream
          .firstWhere((s) => s.notice != null && !s.submitting);
      expect(done.notice!.message, 'Đã mở khóa');
      when(() => locks.unlock(41)).thenThrow(
        const ServerFailure('Không tìm thấy dữ liệu', statusCode: 404),
      );
      bloc.add(const CalendarUnlockRequested(41));
      final failed = await bloc.stream.firstWhere(
        (s) => s.notice?.isError == true && !s.submitting,
      );
      expect(failed.notice!.message, contains('Không tìm thấy'));
      await bloc.close();
    });

    blocTest<CourtCalendarBloc, CourtCalendarState>(
      'đổi sang chế độ ngày chỉ tải đúng một ngày',
      build: calendarBloc,
      act: (bloc) async {
        bloc.add(const CalendarStarted());
        await bloc.stream.firstWhere((s) => s.status == CalendarStatus.ready);
        bloc.add(const CalendarModeChanged(CalendarMode.day));
      },
      verify: (bloc) {
        expect(bloc.state.visibleDates, [DateTime(2030, 1, 9)]);
        verify(
          () => calendar.getDays(5, [DateTime(2030, 1, 9)]),
        ).called(1);
      },
    );
  });

  group('OutOfServiceBloc', () {
    test('gộp khóa đang có theo lệnh (groupId) từ hôm nay', () async {
      when(
        () => locks.getLocks(
          1,
          courtId: any(named: 'courtId'),
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenAnswer(
        (_) async => [
          _lock(id: 2, group: 'b', courtId: 6, start: DateTime(2030, 1, 9, 8), end: DateTime(2030, 1, 9, 9)),
          _lock(id: 1, group: 'b', courtId: 5, start: DateTime(2030, 1, 9, 8), end: DateTime(2030, 1, 9, 9)),
          _lock(id: 3, group: 'a'),
        ],
      );
      final bloc = oosBloc()..add(const OutOfServiceStarted());
      await bloc.stream.firstWhere((s) => s.status == OutOfServiceStatus.ready);
      expect(bloc.state.groups.map((g) => g.groupId), ['a', 'b']);
      expect(bloc.state.groups.last.locks.map((l) => l.courtId), [5, 6]);
      verify(
        () => locks.getLocks(1, from: DateTime(2030, 1, 7)),
      ).called(1);
      await bloc.close();
    });

    test('xung đột booking giữ danh sách slot và không xóa form', () async {
      when(() => locks.lockBranch(any())).thenThrow(
        LockConflictFailure.fromConflicts(const [
          LockConflict(
            courtId: 6,
            date: '2030-01-08',
            startTime: '13:00',
            endTime: '13:30',
            status: 'HOLD',
          ),
        ]),
      );
      final bloc = oosBloc()..add(const OutOfServiceStarted());
      await bloc.stream.firstWhere((s) => s.status == OutOfServiceStatus.ready);
      bloc.add(
        OutOfServiceSubmitted(
          BranchLockRequest(
            branchId: 1,
            allCourts: true,
            startAt: DateTime(2030, 1, 8, 13),
            endAt: DateTime(2030, 1, 8, 18),
            details: _details,
          ),
        ),
      );
      final failed = await bloc.stream.firstWhere((s) => s.conflicts.isNotEmpty);
      expect(failed.notice!.isError, isTrue);
      expect(failed.notice!.saved, isFalse);
      expect(failed.conflicts.single.courtId, 6);
      await bloc.close();
    });

    test('mở khóa nhóm và mở khóa từng sân', () async {
      when(() => locks.unlockGroup('g-1')).thenAnswer((_) async {});
      when(() => locks.unlock(7)).thenAnswer((_) async {});
      final bloc = oosBloc()..add(const OutOfServiceStarted());
      await bloc.stream.firstWhere((s) => s.status == OutOfServiceStatus.ready);
      bloc.add(const OutOfServiceUnlockRequested.group('g-1'));
      await bloc.stream.firstWhere((s) => s.notice?.message == 'Đã mở khóa');
      bloc.add(const OutOfServiceUnlockRequested.lock(7));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      verify(() => locks.unlockGroup('g-1')).called(1);
      verify(() => locks.unlock(7)).called(1);
      await bloc.close();
    });
  });

  group('OutOfServiceWindow', () {
    final now = DateTime(2030, 1, 7, 8);
    OutOfServiceWindow compute({
      DateTime? first,
      DateTime? last,
      bool whole = false,
      ClockTime start = const ClockTime(13, 0),
      ClockTime end = const ClockTime(18, 0),
    }) => OutOfServiceWindow.compute(
      firstDay: first ?? DateTime(2030, 1, 8),
      lastDay: last ?? first ?? DateTime(2030, 1, 8),
      wholeDay: whole,
      startTime: start,
      endTime: end,
      now: now,
    );

    test('chiều Thứ 7 từ 13h đến 18h', () {
      final w = compute();
      expect(w.range!.startAt, DateTime(2030, 1, 8, 13));
      expect(w.range!.endAt, DateTime(2030, 1, 8, 18));
    });

    test('nhiều ngày liên tiếp có giờ riêng và cả ngày', () {
      final multi = compute(last: DateTime(2030, 1, 10));
      expect(multi.range!.endAt, DateTime(2030, 1, 10, 18));
      final whole = compute(whole: true, last: DateTime(2030, 1, 10));
      expect(whole.range!.startAt, DateTime(2030, 1, 8));
      expect(whole.range!.endAt, DateTime(2030, 1, 11));
    });

    test('từ chối giờ lẻ, kết thúc trước bắt đầu, quá khứ và quá 31 ngày', () {
      expect(compute(start: const ClockTime(13, 15)).error, contains('30 phút'));
      expect(compute(end: const ClockTime(12, 0)).error, contains('sau giờ bắt đầu'));
      expect(compute(first: DateTime(2030, 1, 7), end: const ClockTime(7, 0), start: const ClockTime(6, 0)).error, contains('đã qua'));
      expect(compute(last: DateTime(2030, 3, 15)).error, contains('31 ngày'));
      expect(compute(first: DateTime(2030, 1, 10), last: DateTime(2030, 1, 9)).error, contains('Ngày kết thúc'));
    });
  });

  group('CourtCalendarScreen', () {
    Future<CourtCalendarBloc> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final bloc = calendarBloc()..add(const CalendarStarted());
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: bloc,
            child: const CourtCalendarScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return bloc;
    }

    testWidgets('hiện tuần, phân biệt ô trống / đã đặt / bao sân và chú thích', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      expect(find.text('Lịch Sân 5'), findsOneWidget);
      expect(find.text('07/01 - 13/01'), findsOneWidget);
      expect(find.text('Bao sân'), findsOneWidget); // chú thích
      expect(find.bySemanticsLabel('07/01 08:00-08:30, Trống'), findsOneWidget);
      expect(find.bySemanticsLabel('07/01 09:30-10:00, Bao sân'), findsOneWidget);
      expect(find.bySemanticsLabel('07/01 10:00-10:30, Đã đặt'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('chọn ô, nhập lý do và khóa; thiếu lý do bị chặn', (tester) async {
      when(() => locks.lockCourt(any())).thenAnswer((_) async => _lock());
      await pump(tester);
      await tester.tap(find.byKey(const Key('cell-2030-01-07-480')));
      await tester.tap(find.byKey(const Key('cell-2030-01-07-510')));
      await tester.pump();
      expect(find.text('Đã chọn 2 ô'), findsOneWidget);
      await tester.tap(find.byKey(const Key('open-lock-form')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('submit-lock')));
      await tester.pump();
      expect(find.text('Nhập lý do khóa'), findsOneWidget);
      verifyNever(() => locks.lockCourt(any()));

      await tester.tap(find.text('Bao sân sự kiện'));
      await tester.enterText(find.byKey(const Key('lock-reason')), 'Giải đấu');
      await tester.enterText(find.byKey(const Key('lock-contact-phone')), '12');
      await tester.tap(find.byKey(const Key('submit-lock')));
      await tester.pump();
      expect(find.text('Số điện thoại gồm 9-15 chữ số'), findsOneWidget);
      verifyNever(() => locks.lockCourt(any()));

      await tester.enterText(
        find.byKey(const Key('lock-contact-phone')),
        '0901234567',
      );
      await tester.tap(find.byKey(const Key('submit-lock')));
      await tester.pumpAndSettle();

      final request =
          verify(() => locks.lockCourt(captureAny())).captured.single
              as CourtLockRequest;
      expect(request.startAt, DateTime(2030, 1, 7, 8));
      expect(request.endAt, DateTime(2030, 1, 7, 9));
      expect(request.details.type, LockType.privateEvent);
      expect(request.details.contactPhone, '0901234567');
      expect(find.text('Đã khóa khung giờ đã chọn'), findsOneWidget);
    });

    testWidgets('chạm ô đã khóa xem chi tiết và mở khóa sau khi xác nhận', (tester) async {
      when(() => locks.unlock(40)).thenAnswer((_) async {});
      await pump(tester);
      await tester.tap(find.byKey(const Key('cell-2030-01-07-570')));
      await tester.pumpAndSettle();
      expect(find.text('Bao sân sự kiện'), findsOneWidget);
      expect(find.text('Ghi chú: Cọc tiền mặt'), findsOneWidget);
      await tester.tap(find.byKey(const Key('unlock-lock')));
      await tester.pumpAndSettle();
      verifyNever(() => locks.unlock(any()));
      await tester.tap(find.byKey(const Key('confirm-unlock')));
      await tester.pumpAndSettle();
      verify(() => locks.unlock(40)).called(1);
    });

    testWidgets('ô đã đặt không chọn được và báo lý do', (tester) async {
      final bloc = await pump(tester);
      await tester.tap(find.byKey(const Key('cell-2030-01-07-600')));
      await tester.pump();
      expect(bloc.state.selected, isEmpty);
      expect(find.textContaining('đã có khách'), findsOneWidget);
    });
  });

  group('OutOfServiceManagementScreen', () {
    Future<OutOfServiceBloc> pump(
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final bloc = oosBloc()..add(const OutOfServiceStarted());
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: bloc,
            child: OutOfServiceManagementScreen(
              now: () => DateTime(2030, 1, 7, 8),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return bloc;
    }

    testWidgets('bao tất cả sân cả ngày bằng một lệnh và hiện thẻ sự kiện', (tester) async {
      when(() => locks.lockBranch(any())).thenAnswer(
        (_) async => CourtLockGroup(
          groupId: 'g-2',
          locks: [_lock(courtId: 5), _lock(id: 41, courtId: 6)],
        ),
      );
      await pump(tester);
      expect(find.text('Bao sân - FCourt Quận 7'), findsOneWidget);
      expect(find.text('Bao tất cả các sân'), findsOneWidget);
      await tester.tap(find.byKey(const Key('whole-day')));
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('lock-type')),
          matching: find.text('Bao sân sự kiện'),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byKey(const Key('lock-reason')), 'Giải đấu doanh nghiệp');
      await tester.enterText(find.byKey(const Key('lock-public-reason')), 'Giải đấu');
      await tester.tap(find.byKey(const Key('submit-out-of-service')));
      await tester.pumpAndSettle();

      final request =
          verify(() => locks.lockBranch(captureAny())).captured.single
              as BranchLockRequest;
      expect(request.allCourts, isTrue);
      expect(request.courtIds, isEmpty);
      expect(request.branchId, 1);
      expect(request.startAt, DateTime(2030, 1, 8));
      expect(request.endAt, DateTime(2030, 1, 9));
      expect(request.details.type, LockType.privateEvent);
      expect(request.details.publicReason, 'Giải đấu');
      expect(find.textContaining('Đã khóa 2 sân'), findsOneWidget);
    });

    testWidgets('chọn danh sách sân: phải chọn ít nhất một sân; gửi đúng courtIds', (tester) async {
      when(() => locks.lockBranch(any())).thenAnswer(
        (_) async => CourtLockGroup(groupId: 'g-3', locks: [_lock(courtId: 6)]),
      );
      await pump(tester);
      await tester.tap(find.byKey(const Key('all-courts')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('lock-reason')), 'Sửa sàn');
      await tester.tap(find.byKey(const Key('submit-out-of-service')));
      await tester.pump();
      expect(find.text('Chọn ít nhất một sân'), findsOneWidget);
      verifyNever(() => locks.lockBranch(any()));

      await tester.tap(find.byKey(const Key('court-chip-6')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('submit-out-of-service')));
      await tester.pumpAndSettle();
      final request =
          verify(() => locks.lockBranch(captureAny())).captured.single
              as BranchLockRequest;
      expect(request.allCourts, isFalse);
      expect(request.courtIds, [6]);
      expect(request.startAt, DateTime(2030, 1, 8, 13));
      expect(request.endAt, DateTime(2030, 1, 8, 18));
    });

    testWidgets('form không hợp lệ không gọi API; xung đột hiện danh sách slot', (tester) async {
      when(() => locks.lockBranch(any())).thenThrow(
        LockConflictFailure.fromConflicts(const [
          LockConflict(
            courtId: 6,
            date: '2030-01-08',
            startTime: '13:00',
            endTime: '13:30',
            status: 'BOOKED',
          ),
        ]),
      );
      await pump(tester);
      await tester.tap(find.byKey(const Key('submit-out-of-service')));
      await tester.pump();
      expect(find.text('Nhập lý do khóa'), findsOneWidget);
      verifyNever(() => locks.lockBranch(any()));

      await tester.enterText(find.byKey(const Key('lock-reason')), 'Giải đấu');
      await tester.tap(find.byKey(const Key('submit-out-of-service')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lock-conflicts')), findsOneWidget);
      expect(find.textContaining('Sân 6 · 2030-01-08 13:00-13:30 · Đã đặt'), findsOneWidget);
      // form được giữ nguyên để chủ sân đổi khung giờ
      expect(find.text('Giải đấu'), findsWidgets);
    });

    testWidgets('danh sách khóa: mở khóa cả nhóm sau khi xác nhận', (tester) async {
      when(
        () => locks.getLocks(
          1,
          courtId: any(named: 'courtId'),
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenAnswer(
        (_) async => [_lock(id: 1, group: 'g-1', courtId: 5), _lock(id: 2, group: 'g-1', courtId: 6)],
      );
      when(() => locks.unlockGroup('g-1')).thenAnswer((_) async {});
      await pump(tester);
      expect(find.byKey(const Key('lock-group-g-1')), findsOneWidget);
      expect(find.text('Tất cả các sân'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('unlock-group-g-1')));
      await tester.tap(find.byKey(const Key('unlock-group-g-1')));
      await tester.pumpAndSettle();
      verifyNever(() => locks.unlockGroup(any()));
      await tester.tap(find.byKey(const Key('confirm-unlock')));
      await tester.pumpAndSettle();
      verify(() => locks.unlockGroup('g-1')).called(1);
    });
  });
}
