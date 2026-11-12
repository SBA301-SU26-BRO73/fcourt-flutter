import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/sport_icon.dart';
import '../domain/booking.dart';

/// Look of a booking in the customer screens (mock-up "order" card): which
/// photo, sport label, status tag and money format to use.
extension BookingStyle on Booking {
  /// Sport guessed from the venue and court names; [SportKind.other] when the
  /// names say nothing.
  SportKind get sportKind => sportKindOf('$branchName $courtName');

  /// "Cầu lông", "Tennis"... or null when the sport is unknown.
  String? get sportLabel => switch (sportKind) {
    SportKind.badminton => 'Cầu lông',
    SportKind.pickleball => 'Pickleball',
    SportKind.tennis => 'Tennis',
    SportKind.football => 'Bóng đá',
    SportKind.basketball => 'Bóng rổ',
    SportKind.volleyball => 'Bóng chuyền',
    SportKind.other => null,
  };

  /// "Cầu lông · Sân 2".
  String get sportAndCourt => [
    sportLabel,
    courtName,
  ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

  /// "12/11/2026".
  String get dateText {
    final parsed = DateTime.tryParse(date);
    return parsed == null ? date : DateFormat('dd/MM/yyyy').format(parsed);
  }

  /// "12/11/2026 · 07:00–09:00".
  String get dateAndSlots {
    final slotText = mergeSlotRanges(slots).join(' · ');
    return slotText.isEmpty ? dateText : '$dateText · $slotText';
  }

  /// "100.000đ".
  String get amountText => formatVnd(amount);

  StatusTone tone(BuildContext context) => switch (status) {
    'CANCELLED' => context.fc.danger,
    'CONFIRMED' || 'CHECKED_IN' || 'COMPLETED' => context.fc.success,
    _ => context.fc.warning,
  };

  IconData get statusIcon => switch (status) {
    'CANCELLED' => Icons.close,
    'CONFIRMED' || 'CHECKED_IN' || 'COMPLETED' => Icons.check,
    _ => Icons.schedule,
  };

  /// Short label used on tags: "Đã xác nhận" for any confirmed state.
  String get tagLabel => switch (status) {
    'CONFIRMED' => 'Đã xác nhận',
    _ => label,
  };
}

String formatVnd(num amount) =>
    '${NumberFormat.decimalPattern('vi').format(amount)}đ';

/// Weekday name of a date: "Thứ Năm", "Chủ nhật".
String weekdayName(DateTime date) => const [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ nhật',
][date.weekday - 1];
