import 'package:flutter/material.dart';

import '../../../app/widgets/fc_widgets.dart';
import '../domain/admin_booking_status.dart';

class BookingStatusBadge extends StatelessWidget {
  const BookingStatusBadge(this.status, {super.key});
  final AdminBookingStatus status;

  static StatusTone tone(BuildContext context, AdminBookingStatus status) =>
      switch (status) {
        AdminBookingStatus.confirmed ||
        AdminBookingStatus.completed => context.fc.success,
        AdminBookingStatus.pendingPayment ||
        AdminBookingStatus.awaitingConfirmation => context.fc.warning,
        AdminBookingStatus.cancelled => context.fc.danger,
        AdminBookingStatus.checkedIn => context.fc.info,
      };

  @override
  Widget build(BuildContext context) =>
      StatusPill(status.label, tone: tone(context, status));
}
