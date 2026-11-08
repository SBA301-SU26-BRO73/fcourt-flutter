import 'package:equatable/equatable.dart';

/// Trạng thái một ô trên lịch quản trị. `locked` gồm cả ngừng phục vụ lẫn bao sân.
enum CalendarSlotStatus { available, booked, hold, locked, expired, unknown }

/// Một ô 30 phút của sân trong một ngày, đọc từ discovery-service (cùng nguồn
/// với màn đặt sân của khách) để chủ sân thấy đúng cái khách thấy.
class CalendarSlot extends Equatable {
  const CalendarSlot({
    required this.startMinute,
    required this.endMinute,
    required this.status,
    this.isPrivateEvent = false,
    this.publicReason,
  });

  /// Phút trong ngày; ô cuối ngày có `endMinute == 1440`.
  final int startMinute;
  final int endMinute;
  final CalendarSlotStatus status;
  final bool isPrivateEvent;
  final String? publicReason;

  bool get selectable => status == CalendarSlotStatus.available;

  @override
  List<Object?> get props => [
    startMinute,
    endMinute,
    status,
    isPrivateEvent,
    publicReason,
  ];
}

/// Lịch một ngày của một sân.
class CalendarDay extends Equatable {
  const CalendarDay({required this.date, required this.slots});

  final DateTime date;
  final List<CalendarSlot> slots;

  CalendarSlot? slotAt(int startMinute) {
    for (final slot in slots) {
      if (slot.startMinute == startMinute) return slot;
    }
    return null;
  }

  @override
  List<Object?> get props => [date, slots];
}

/// Khóa ô đã chọn: ngày (00:00 địa phương) và phút bắt đầu.
class CellKey extends Equatable implements Comparable<CellKey> {
  const CellKey(this.date, this.startMinute);

  final DateTime date;
  final int startMinute;

  @override
  int compareTo(CellKey other) {
    final byDate = date.compareTo(other.date);
    return byDate != 0 ? byDate : startMinute.compareTo(other.startMinute);
  }

  @override
  List<Object?> get props => [date, startMinute];
}

/// Khoảng thời gian liên tục `[startAt, endAt)` gộp từ các ô được chọn.
class LockRange extends Equatable {
  const LockRange(this.startAt, this.endAt);

  final DateTime startAt;
  final DateTime endAt;

  @override
  List<Object?> get props => [startAt, endAt];
}

/// Gộp các ô đã chọn thành những khoảng liên tục: hai ô liền kề (kể cả qua nửa
/// đêm, 23:30 rồi 00:00 hôm sau) nằm chung một khoảng, nên một lệnh khóa không
/// bị cắt nhỏ. [slotEnd] cho biết phút kết thúc của từng ô (1440 = nửa đêm).
List<LockRange> mergeSelection(
  Iterable<CellKey> selected,
  int Function(CellKey cell) slotEnd,
) {
  final cells = selected.toList()..sort();
  final ranges = <LockRange>[];
  DateTime? start;
  DateTime? end;
  for (final cell in cells) {
    final cellStart = cell.date.add(Duration(minutes: cell.startMinute));
    final cellEnd = cell.date.add(Duration(minutes: slotEnd(cell)));
    if (end != null && cellStart == end) {
      end = cellEnd;
    } else {
      if (start != null && end != null) ranges.add(LockRange(start, end));
      start = cellStart;
      end = cellEnd;
    }
  }
  if (start != null && end != null) ranges.add(LockRange(start, end));
  return ranges;
}

/// Cửa sổ "cả ngày" cho các ngày liên tiếp: 00:00 ngày đầu đến 00:00 sau ngày cuối.
LockRange wholeDays(DateTime firstDay, DateTime lastDay) => LockRange(
  DateTime(firstDay.year, firstDay.month, firstDay.day),
  DateTime(lastDay.year, lastDay.month, lastDay.day + 1),
);
