import 'package:fcourt/features/admin_bookings/domain/admin_booking.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking_query.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking_repository.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking_status.dart';
import 'package:fcourt/features/admin_bookings/presentation/admin_booking_cubit.dart';
import 'package:fcourt/features/admin_bookings/presentation/admin_booking_management_screen.dart';
import 'package:fcourt/features/admin_facility/domain/entities/calendar_slot.dart';
import 'package:fcourt/features/admin_facility/domain/repositories/court_lock_repository.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/branch_usecases.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/court_usecases.dart';
import 'package:fcourt/features/admin_facility/domain/usecases/lock_usecases.dart';
import 'package:fcourt/features/admin_facility/presentation/bloc/branch_form_bloc.dart';
import 'package:fcourt/features/admin_facility/presentation/bloc/court_calendar_bloc.dart';
import 'package:fcourt/features/admin_facility/presentation/pages/branch_form_screen.dart';
import 'package:fcourt/features/admin_facility/presentation/pages/court_calendar_screen.dart';
import 'package:fcourt/features/transactions/presentation/customer_transaction_history_screen.dart';
import 'package:fcourt/features/vouchers/presentation/voucher_editor.dart';
import 'package:fcourt/src/features/branch_gallery/presentation/admin_branch_images_cubit.dart';
import 'package:fcourt/src/features/branch_gallery/presentation/admin_branch_images_screen.dart';
import 'package:fcourt/src/features/branch_gallery/presentation/widgets/branch_image_view.dart';
import 'package:fcourt/app/theme/sport_images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/owner_shot.dart';
import 'admin_facility/fixtures.dart';
import 'admin_facility/mocks.dart';
import 'branch_gallery/gallery_helpers.dart';
import 'transactions/customer_transactions_test.dart' show Transactions;
import 'vouchers/editor_test.dart' show EditorRepository;

class _Locks extends Mock implements CourtLockRepository {}

class _Calendar extends Mock implements CourtCalendarRepository {}

class _Bookings implements AdminBookingRepository {
  @override
  Future<AdminBookingPage> search(
    AdminBookingQuery query, {
    int page = 0,
  }) async => AdminBookingPage(
    [
      AdminBooking(
        id: 1,
        code: 'FC2418',
        branchId: 1,
        branchName: 'FCourt Quận 7',
        courtId: 1,
        courtName: 'Sân 1',
        date: DateTime(2026, 11, 12),
        createdAt: DateTime.utc(2026, 11, 12, 1),
        status: AdminBookingStatus.confirmed,
        amount: 100000,
        customerName: 'Nguyễn Hoàng An',
        customerPhone: '0901234561',
        paymentStatus: 'PENDING',
      ),
    ],
    0,
    1,
  );
}

CalendarSlot _slot(
  int start,
  CalendarSlotStatus status, {
  bool event = false,
}) => CalendarSlot(
  startMinute: start,
  endMinute: start + 60,
  status: status,
  isPrivateEvent: event,
);

List<CalendarDay> _week() => [
  for (var i = 0; i < 7; i++)
    CalendarDay(
      date: DateTime(2030, 1, 7 + i),
      slots: [
        _slot(480, CalendarSlotStatus.available),
        _slot(
          540,
          i == 2 ? CalendarSlotStatus.hold : CalendarSlotStatus.available,
        ),
        _slot(
          600,
          i.isEven ? CalendarSlotStatus.booked : CalendarSlotStatus.available,
        ),
        _slot(
          660,
          i == 0 ? CalendarSlotStatus.locked : CalendarSlotStatus.available,
          event: true,
        ),
        _slot(
          720,
          i == 3 ? CalendarSlotStatus.locked : CalendarSlotStatus.available,
        ),
        _slot(780, CalendarSlotStatus.expired),
      ],
    ),
];

void main() {
  for (final b in Brightness.values) {
    testWidgets('branch form (${b.name})', (tester) async {
      final branches = MockBranchRepository();
      when(() => branches.getBranch(1)).thenAnswer((_) async => sampleBranch());
      await pumpOwner(
        tester,
        b,
        BlocProvider(
          create: (_) => BranchFormBloc(
            getBranch: GetBranch(branches),
            saveBranch: SaveBranch(branches),
            branchId: 1,
          )..add(const BranchFormStarted()),
          child: const BranchFormScreen(),
        ),
        nav: false,
        withBack: true,
        shot: 'owner-branch-form',
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Lưu thay đổi'), findsOneWidget);
    });

    for (final locking in [false, true]) {
      testWidgets(
        'court calendar ${locking ? 'lock sheet' : 'selection'} (${b.name})',
        (tester) async {
          final locks = _Locks();
          final calendar = _Calendar();
          final courts = MockCourtRepository();
          when(() => courts.getCourt(5)).thenAnswer((_) async => sampleCourt());
          when(() => calendar.getDays(5, any()))
              .thenAnswer((_) async => _week());
          when(
            () => locks.getLocks(
              1,
              courtId: any(named: 'courtId'),
              from: any(named: 'from'),
              to: any(named: 'to'),
            ),
          ).thenAnswer((_) async => const []);
          final bloc = CourtCalendarBloc(
            courtId: 5,
            getCourt: GetCourt(courts),
            getDays: GetCalendarDays(calendar),
            getLocks: GetCourtLocks(locks),
            lockCourt: LockCourt(locks),
            unlockCourt: UnlockCourt(locks),
            today: () => DateTime(2030, 1, 9, 15),
            now: () => DateTime.utc(2030, 1, 7, 0),
          )..add(const CalendarStarted());
          addTearDown(bloc.close);
          final key = await pumpOwner(
            tester,
            b,
            BlocProvider.value(value: bloc, child: const CourtCalendarScreen()),
            nav: false,
            withBack: true,
            shot: locking ? null : 'owner-court-calendar',
            before: (t) async {
              await t.tap(find.byKey(const Key('cell-2030-01-08-480')));
              await t.tap(find.byKey(const Key('cell-2030-01-09-480')));
              await t.pumpAndSettle();
              if (locking) {
                await t.tap(find.byKey(const Key('open-lock-form')));
                await t.pumpAndSettle();
              }
            },
          );
          if (locking) await ownerShot(tester, key, 'owner-lock-sheet', b);
          // Fallback glyphs are wider than the bundled font, so only the
          // real-font run (WP3B_SHOTS) must be overflow-free.
          final error = tester.takeException();
          if (ownerShotDir != null) expect(error, isNull);
        },
      );
    }

    testWidgets('orders filter sheet (${b.name})', (tester) async {
      final courts = MockCourtRepository();
      when(() => courts.getCourts(1)).thenAnswer((_) async => [sampleCourt()]);
      final branches = MockBranchRepository();
      when(() => branches.getBranches())
          .thenAnswer((_) async => [sampleBranch()]);
      final cubit = AdminBookingCubit(_Bookings(), branches, courts)
        ..initialize();
      addTearDown(cubit.close);
      final key = await pumpOwner(
        tester,
        b,
        BlocProvider.value(
          value: cubit,
          child: const AdminBookingManagementScreen(),
        ),
        withBack: true,
        navIndex: 1,
        before: (t) async {
          await t.tap(find.byKey(const ValueKey('open-filters')));
          await t.pumpAndSettle();
        },
      );
      await ownerShot(tester, key, 'owner-orders-filter', b);
      expect(find.text('Bộ lọc'), findsWidgets);
    });

    testWidgets('voucher editor (${b.name})', (tester) async {
      final key = await pumpOwner(
        tester,
        b,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => VoucherEditor(
                  repository: EditorRepository(),
                  branchId: 1,
                  id: 1,
                ),
              ),
              child: const Text('Mở form'),
            ),
          ),
        ),
        nav: false,
        before: (t) async {
          await t.tap(find.text('Mở form'));
          await t.pumpAndSettle();
        },
      );
      await ownerShot(tester, key, 'owner-voucher-editor', b);
      expect(find.text('Lưu voucher'), findsOneWidget);
    });

    testWidgets('branch photos (${b.name})', (tester) async {
      BranchImageView.debugBuilder = (url, fit) => Image.asset(
        SportImages.placeholderFor(url.contains('/2') ? 'Tennis' : 'Cầu lông'),
        fit: fit,
      );
      addTearDown(() => BranchImageView.debugBuilder = null);
      await pumpOwner(
        tester,
        b,
        BlocProvider(
          create: (_) => AdminBranchImagesCubit(
            repository: FakeBranchImages([1, 2, 3].map(image).toList()),
            picker: FakePicker(),
            branchId: 3,
          )..load(),
          child: const AdminBranchImagesScreen(
            branchName: 'Sân Cầu Lông Ba Đình',
          ),
        ),
        nav: false,
        withBack: true,
        shot: 'owner-branch-photos',
      );
      expect(find.text('3/10 ảnh'), findsOneWidget);
    });

    testWidgets('customer transactions (${b.name})', (tester) async {
      await pumpOwner(
        tester,
        b,
        CustomerTransactionHistoryScreen(repository: Transactions()),
        nav: false,
        withBack: true,
        shot: 'customer-transactions',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
