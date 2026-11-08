part of 'bulk_apply_template_bloc.dart';

enum BulkApplyStatus { editing, previewing, preview, applying, done }

class BulkApplyTemplateState extends Equatable {
  const BulkApplyTemplateState({
    required this.courts,
    required this.start,
    required this.end,
    this.branchOpen,
    this.branchClose,
    this.selectedIds = const {},
    this.price,
    this.daysOfWeek = const {0, 1, 2, 3, 4, 5, 6},
    this.status = BulkApplyStatus.editing,
    this.preview,
    this.applied,
    this.error,
  });

  final List<Court> courts;
  final ClockTime start;
  final ClockTime end;
  final ClockTime? branchOpen;
  final ClockTime? branchClose;
  final Set<int> selectedIds;

  /// Giá mỗi slot (VND); `null` = theo giá giờ của từng sân.
  final int? price;
  final Set<int> daysOfWeek;
  final BulkApplyStatus status;
  final BulkPreview? preview;
  final BulkApplied? applied;

  /// Lỗi của lần gọi API gần nhất (hiện trong hộp thoại, không đóng hộp thoại).
  final String? error;

  bool get busy =>
      status == BulkApplyStatus.previewing ||
      status == BulkApplyStatus.applying;

  bool get allSelected =>
      courts.isNotEmpty && selectedIds.length == courts.length;

  List<Court> get selectedCourts => [
    for (final court in courts)
      if (selectedIds.contains(court.id)) court,
  ];

  /// Sân đã chọn nhưng chưa có giá giờ trong khi chưa nhập giá mỗi slot.
  List<Court> get courtsMissingPrice => price != null
      ? const []
      : [
          for (final court in selectedCourts)
            if (court.defaultPricePerHour == null) court,
        ];

  SlotRangeIssue? get rangeIssue => validateSlotRange(
    start: start,
    end: end,
    branchOpen: branchOpen,
    branchClose: branchClose,
  );

  /// Request hợp lệ, hoặc `null` nếu còn lỗi cần sửa.
  BulkSlotTemplateRequest? get request {
    if (selectedIds.isEmpty ||
        selectedIds.length > maxBulkCourts ||
        daysOfWeek.isEmpty ||
        (price != null && price! <= 0) ||
        courtsMissingPrice.isNotEmpty ||
        rangeIssue != null) {
      return null;
    }
    return BulkSlotTemplateRequest(
      courtIds: selectedCourts.map((c) => c.id).toList(),
      startTime: start,
      endTime: end,
      price: price,
      daysOfWeek: daysOfWeek.toList()..sort(),
    );
  }

  BulkApplyTemplateState copyWith({
    Set<int>? selectedIds,
    ClockTime? start,
    ClockTime? end,
    int? price,
    bool clearPrice = false,
    Set<int>? daysOfWeek,
    BulkApplyStatus? status,
    BulkPreview? preview,
    BulkApplied? applied,
    String? error,
  }) => BulkApplyTemplateState(
    courts: courts,
    start: start ?? this.start,
    end: end ?? this.end,
    branchOpen: branchOpen,
    branchClose: branchClose,
    selectedIds: selectedIds ?? this.selectedIds,
    price: clearPrice ? null : price ?? this.price,
    daysOfWeek: daysOfWeek ?? this.daysOfWeek,
    status: status ?? this.status,
    preview: preview ?? this.preview,
    applied: applied ?? this.applied,
    // Lỗi chỉ sống đến lần emit kế tiếp.
    error: error,
  );

  @override
  List<Object?> get props => [
    courts,
    start,
    end,
    branchOpen,
    branchClose,
    selectedIds,
    price,
    daysOfWeek,
    status,
    preview,
    applied,
    error,
  ];
}
