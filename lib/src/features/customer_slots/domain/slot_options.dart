import 'package:intl/intl.dart';

import 'court_slot.dart';

/// A court the customer can book inside the branch.
class PickerCourt {
  const PickerCourt({required this.id, required this.name});
  final int id;
  final String name;
}

/// Part of the day used to group start times.
enum DayPart {
  morning('Sáng'),
  afternoon('Chiều'),
  evening('Tối');

  const DayPart(this.label);
  final String label;

  static DayPart of(int startMinute) => startMinute < 12 * 60
      ? morning
      : startMinute < 18 * 60
      ? afternoon
      : evening;
}

/// Durations offered by the picker, in minutes.
const slotDurations = [60, 90, 120];

String durationLabel(int minutes) => switch (minutes) {
  60 => '1 giờ',
  90 => '1,5 giờ',
  120 => '2 giờ',
  _ => '$minutes phút',
};

/// One start time of the picker list for the chosen duration and court filter.
class StartOption {
  const StartOption({
    required this.startMinute,
    required this.durationMinutes,
    required this.courtIds,
    required this.priceMinor,
    this.blockedLabel,
  });

  final int startMinute, durationMinutes;

  /// Courts that are free for the whole duration, in branch order.
  final List<int> courtIds;

  /// Price of [suggestedCourtId] for the whole duration.
  final int priceMinor;

  /// Why nothing is bookable ("Đã đặt", "Đã qua"...); null when available.
  final String? blockedLabel;

  bool get available => courtIds.isNotEmpty;
  int get endMinute => startMinute + durationMinutes;
  int? get suggestedCourtId => courtIds.isEmpty ? null : courtIds.first;
  DayPart get part => DayPart.of(startMinute);
}

/// The 30-minute cells of [courtId] that make up a booking starting at
/// [startMinute]; null when any cell is missing or not bookable.
List<CourtSlot>? bookableCells(
  List<CourtSlot> slots,
  int startMinute,
  int durationMinutes,
) {
  final byStart = {for (final s in slots) s.startMinute: s};
  final cells = <CourtSlot>[];
  for (var m = startMinute; m < startMinute + durationMinutes; m += 30) {
    final cell = byStart[m];
    if (cell == null || cell.status != SlotStatus.available) return null;
    cells.add(cell);
  }
  return cells;
}

/// Builds the start-time list. Starts that cannot fit the duration (end of the
/// schedule) are omitted; starts blocked on every considered court are kept
/// with a [StartOption.blockedLabel] so the UI can show them on request.
List<StartOption> buildStartOptions({
  required List<PickerCourt> courts,
  required Map<int, List<CourtSlot>> slotsByCourt,
  required int? courtFilter,
  required int durationMinutes,
}) {
  final considered = courts
      .where((c) => courtFilter == null || c.id == courtFilter)
      .toList();
  final starts = <int>{
    for (final court in considered)
      for (final slot in slotsByCourt[court.id] ?? const <CourtSlot>[])
        slot.startMinute,
  }.toList()..sort();

  final options = <StartOption>[];
  for (final start in starts) {
    final free = <int>[];
    var price = 0;
    final blocked = <CourtSlot>[];
    var fits = false;
    for (final court in considered) {
      final slots = slotsByCourt[court.id] ?? const <CourtSlot>[];
      final byStart = {for (final s in slots) s.startMinute: s};
      CourtSlot? firstBlock;
      var complete = true;
      for (var m = start; m < start + durationMinutes; m += 30) {
        final cell = byStart[m];
        if (cell == null) {
          complete = false;
          break;
        }
        if (cell.status != SlotStatus.available) firstBlock ??= cell;
      }
      if (!complete) continue;
      fits = true;
      if (firstBlock == null) {
        if (free.isEmpty) {
          price = bookableCells(
            slots,
            start,
            durationMinutes,
          )!.fold(0, (sum, cell) => sum + cell.priceMinor);
        }
        free.add(court.id);
      } else {
        blocked.add(firstBlock);
      }
    }
    if (!fits) continue;
    String? label;
    if (free.isEmpty) {
      final live = blocked.where((s) => s.status != SlotStatus.expired);
      label = live.isEmpty ? SlotStatus.expired.label : live.first.displayLabel;
    }
    options.add(
      StartOption(
        startMinute: start,
        durationMinutes: durationMinutes,
        courtIds: free,
        priceMinor: price,
        blockedLabel: label,
      ),
    );
  }
  return options;
}

extension SlotAppearance on SlotStatus {
  String get label => switch (this) {
    SlotStatus.available => 'Trống',
    SlotStatus.booked => 'Đã đặt',
    SlotStatus.hold => 'Đang giữ',
    SlotStatus.outOfService => 'Ngừng phục vụ',
    SlotStatus.expired => 'Đã qua',
    SlotStatus.unknown => 'Không khả dụng',
  };
}

extension RestrictedSlotAppearance on CourtSlot {
  bool get isPrivateEvent =>
      status == SlotStatus.outOfService && restriction?.isPrivateEvent == true;
  String get displayLabel => isPrivateEvent ? 'Bao sân' : status.label;
}

String slotTime(int minute) =>
    '${((minute ~/ 60) % 24).toString().padLeft(2, '0')}:'
    '${(minute % 60).toString().padLeft(2, '0')}';

String slotMoney(int minor) =>
    '${NumberFormat('#,##0.##', 'vi').format(minor / 100)}đ';
