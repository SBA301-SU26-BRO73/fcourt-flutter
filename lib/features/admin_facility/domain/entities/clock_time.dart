import 'package:equatable/equatable.dart';

/// Giờ trong ngày (không phụ thuộc Flutter `TimeOfDay`) để tầng domain thuần Dart.
class ClockTime extends Equatable implements Comparable<ClockTime> {
  const ClockTime(this.hour, this.minute)
    : assert(hour >= 0 && hour < 24),
      assert(minute >= 0 && minute < 60);

  const ClockTime.fromMinutes(int minutes) : this(minutes ~/ 60, minutes % 60);

  final int hour;
  final int minute;

  int get inMinutes => hour * 60 + minute;

  /// Nhận `"HH:mm"` hoặc `"HH:mm:ss"` như backend trả về.
  static ClockTime? tryParse(Object? value) {
    if (value is! String) return null;
    final match = RegExp(r'^(\d{2}):(\d{2})(?::\d{2})?$').firstMatch(value);
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) return null;
    return ClockTime(hour, minute);
  }

  /// Định dạng `"HH:mm"` dùng cho cả request và hiển thị.
  String format() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  bool isBefore(ClockTime other) => inMinutes < other.inMinutes;

  @override
  int compareTo(ClockTime other) => inMinutes.compareTo(other.inMinutes);

  @override
  List<Object?> get props => [hour, minute];

  @override
  String toString() => format();
}
