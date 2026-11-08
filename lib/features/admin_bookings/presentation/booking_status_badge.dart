import 'package:flutter/material.dart';

import '../domain/admin_booking_status.dart';

class BookingStatusBadge extends StatelessWidget {
  const BookingStatusBadge(this.status, {super.key});
  final AdminBookingStatus status;

  static Color color(AdminBookingStatus status) => switch (status) {
    AdminBookingStatus.confirmed ||
    AdminBookingStatus.completed => const Color(0xFF2E7D32),
    AdminBookingStatus.pendingPayment ||
    AdminBookingStatus.awaitingConfirmation => const Color(0xFFF9A825),
    AdminBookingStatus.cancelled => const Color(0xFFC62828),
    AdminBookingStatus.checkedIn => const Color(0xFF1565C0),
  };

  @override
  Widget build(BuildContext context) {
    final value = color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: value.withValues(alpha: .15),
        border: Border.all(color: value),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: value,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
