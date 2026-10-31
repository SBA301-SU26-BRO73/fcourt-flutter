import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/clock_time.dart';

/// "120.000 đ" — định dạng tiền VND đầy đủ.
String formatVnd(int amount) =>
    '${NumberFormat.decimalPattern('vi').format(amount)} đ';

ClockTime clockFromTimeOfDay(TimeOfDay time) =>
    ClockTime(time.hour, time.minute);

TimeOfDay timeOfDayFromClock(ClockTime time) =>
    TimeOfDay(hour: time.hour, minute: time.minute);

/// Mở TimePicker 24 giờ, trả về `null` khi người dùng hủy.
Future<ClockTime?> pickClockTime(
  BuildContext context, {
  required ClockTime initial,
  String? helpText,
}) async {
  final picked = await showTimePicker(
    context: context,
    initialTime: timeOfDayFromClock(initial),
    helpText: helpText,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  return picked == null ? null : clockFromTimeOfDay(picked);
}

/// Thông báo lỗi tải dữ liệu kèm nút thử lại.
class FacilityErrorView extends StatelessWidget {
  const FacilityErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}
