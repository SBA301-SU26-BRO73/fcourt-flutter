import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking_repository.dart';
import 'package:fcourt/features/admin_bookings/domain/admin_booking_status.dart';
import 'package:fcourt/features/admin_bookings/presentation/admin_booking_cubit.dart';
import 'package:fcourt/features/admin_bookings/presentation/admin_booking_management_screen.dart';
import 'package:fcourt/features/admin_bookings/presentation/admin_booking_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cubit_test.dart' show setup, initialize, bookingRow;

void main() {
  testWidgets(
    'mobile search court status and date controls update booking query',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (cubit, repository, _, _) = setup();
      addTearDown(cubit.close);
      await initialize(tester, cubit, repository);
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: const MaterialApp(home: AdminBookingManagementScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0901');
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.calls.last.query.search, '0901');
      repository.calls.last.result.complete(
        AdminBookingPage([bookingRow(1)], 0, 1),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sân 5').last);
      await tester.pump();
      expect(repository.calls.last.query.courtId, 5);
      repository.calls.last.result.complete(
        AdminBookingPage([bookingRow(1)], 0, 1),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byType(DropdownButtonFormField<AdminBookingStatus>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đã xác nhận').last);
      await tester.pump();
      expect(repository.calls.last.query.status, AdminBookingStatus.confirmed);
      repository.calls.last.result.complete(
        AdminBookingPage([bookingRow(1)], 0, 1),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn ngày chơi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pump();
      expect(repository.calls.last.query.date, isNotNull);
      repository.calls.last.result.complete(const AdminBookingPage([], 0, 0));
      await tester.pumpAndSettle();
      expect(find.text('Không có đơn đặt sân phù hợp'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
