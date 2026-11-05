import 'dart:async';

import 'package:fcourt/features/admin_facility/domain/entities/court.dart';

import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking_query.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking_repository.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking_status.dart';
import 'package:fcourt/features/admin_bookings/presentation/admin_booking_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../admin_facility/fixtures.dart';
import '../admin_facility/mocks.dart';

AdminBooking bookingRow(int id, {int branchId = 1}) => AdminBooking(
  id: id,
  code: 'BK$id',
  branchId: branchId,
  branchName: 'Chi nhánh $branchId',
  courtId: branchId == 1 ? 5 : 10,
  courtName: branchId == 1 ? 'Sân 5' : 'Sân 10',
  date: DateTime(2026, 11, 5),
  createdAt: DateTime.utc(2026, 11, 4),
  status: AdminBookingStatus.confirmed,
  amount: 125000.25,
);

class PendingBookings implements AdminBookingRepository {
  final calls =
      <
        ({
          AdminBookingQuery query,
          int page,
          Completer<AdminBookingPage> result,
        })
      >[];
  @override
  Future<AdminBookingPage> search(AdminBookingQuery query, {int page = 0}) {
    final call = (
      query: query,
      page: page,
      result: Completer<AdminBookingPage>(),
    );
    calls.add(call);
    return call.result.future;
  }
}

(AdminBookingCubit, PendingBookings, MockBranchRepository, MockCourtRepository)
setup() {
  final branches = MockBranchRepository();
  final courts = MockCourtRepository();
  when(() => branches.getBranches())
      .thenAnswer((_) async => [sampleBranch(), sampleBranch(id: 2)]);
  when(() => courts.getCourts(1)).thenAnswer((_) async => [sampleCourt()]);
  when(() => courts.getCourts(2))
      .thenAnswer((_) async => [sampleCourt(id: 10, branchId: 2)]);
  final repository = PendingBookings();
  return (
    AdminBookingCubit(repository, branches, courts),
    repository,
    branches,
    courts,
  );
}

Future<void> initialize(
  WidgetTester tester,
  AdminBookingCubit cubit,
  PendingBookings repository,
) async {
  final pending = cubit.initialize();
  await tester.pump();
  repository.calls.last.result.complete(
    AdminBookingPage([bookingRow(1)], 0, 41),
  );
  await pending;
}

void main() {
  testWidgets('late courts and bookings from previous branch are ignored', (
    tester,
  ) async {
    final (cubit, repository, _, courts) = setup();
    await initialize(tester, cubit, repository);
    final lateCourts = Completer<List<Court>>();
    when(() => courts.getCourts(1)).thenAnswer((_) => lateCourts.future);
    final oldCourts = cubit.reloadCourts();
    final oldBookings = cubit.loadMore();
    final stale = repository.calls.last;
    final switchBranch = cubit.selectBranch(2);
    expect(repository.calls.last.query.branchId, 2);
    repository.calls.last.result.complete(
      AdminBookingPage([bookingRow(2, branchId: 2)], 0, 1),
    );
    await switchBranch;
    lateCourts.complete([sampleCourt()]);
    await oldCourts;
    stale.result.complete(AdminBookingPage([bookingRow(99)], 1, 41));
    await oldBookings;
    expect(cubit.state.query!.branchId, 2);
    expect(cubit.state.courts.single.id, 10);
    expect(cubit.state.items.single.id, 2);
    await cubit.close();
  });
  testWidgets(
    'search debounces and stale responses cannot replace changed filters',
    (tester) async {
      final (cubit, repository, _, _) = setup();
      await initialize(tester, cubit, repository);
      final old = cubit.refresh();
      final stale = repository.calls.last;
      cubit.search('0901');
      await tester.pump(const Duration(milliseconds: 150));
      cubit.search('09012');
      stale.result.complete(AdminBookingPage([bookingRow(99)], 0, 1));
      await old;
      expect(cubit.state.items, isEmpty);
      await tester.pump(const Duration(milliseconds: 299));
      expect(repository.calls.length, 2);
      await tester.pump(const Duration(milliseconds: 1));
      expect(repository.calls.last.query.search, '09012');
      repository.calls.last.result.complete(
        AdminBookingPage([bookingRow(2)], 0, 1),
      );
      await tester.pump();
      cubit.setCourt(5);
      expect(repository.calls.last.query.search, '09012');
      expect(repository.calls.last.query.courtId, 5);
      repository.calls.last.result.complete(
        AdminBookingPage([bookingRow(2)], 0, 1),
      );
      await tester.pump();
      expect(cubit.state.items.single.id, 2);
      await cubit.close();
    },
  );
}
