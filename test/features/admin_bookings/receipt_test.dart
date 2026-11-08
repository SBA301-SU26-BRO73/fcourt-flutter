import 'package:fcourt/features/admin_bookings/domain/admin_booking.dart';
import 'package:fcourt/features/admin_bookings/presentation/admin_booking_detail.dart';
import 'package:fcourt/features/admin_bookings/presentation/admin_receipt_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cubit_test.dart' show bookingRow;

void main() {
  testWidgets(
    'provided receipt opens from details and image loader has no credentials',
    (tester) async {
      final row = bookingRow(1);
      final uri = Uri.parse(
        'https://res.cloudinary.com/fcourt/image/upload/receipt.png',
      );
      final booking = AdminBooking(
        id: row.id,
        code: row.code,
        branchId: row.branchId,
        branchName: row.branchName,
        courtId: row.courtId,
        courtName: row.courtName,
        date: row.date,
        createdAt: row.createdAt,
        status: row.status,
        amount: row.amount,
        receiptUri: uri,
      );
      Uri? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: AdminBookingDetail(
            booking: booking,
            receiptBuilder: (value) {
              opened = value;
              return const Text('Ảnh biên lai');
            },
          ),
        ),
      );
      await tester.tap(find.text('Xem biên lai'));
      await tester.pumpAndSettle();
      expect(opened, uri);
      expect(find.text('Ảnh biên lai'), findsOneWidget);
      await tester.pumpWidget(MaterialApp(home: AdminReceiptScreen(uri: uri)));
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as NetworkImage).url, uri.toString());
      expect((image.image as NetworkImage).headers, isNull);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
