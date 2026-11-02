part of 'slot_template_bloc.dart';

enum SlotTemplateStatus { loading, loadFailure, ready }

class SlotTemplateNotice {
  SlotTemplateNotice(this.message, {this.isError = false});

  final String message;
  final bool isError;
}

class SlotTemplateState extends Equatable {
  const SlotTemplateState({
    this.status = SlotTemplateStatus.loading,
    this.court,
    this.branch,
    this.start,
    this.end,
    this.price,
    this.daysOfWeek = const {0, 1, 2, 3, 4, 5, 6},
    this.applying = false,
    this.message,
    this.notice,
  });

  final SlotTemplateStatus status;
  final Court? court;
  final Branch? branch;
  final ClockTime? start;
  final ClockTime? end;

  /// Giá mỗi slot (VND).
  final int? price;
  final Set<int> daysOfWeek;
  final bool applying;
  final String? message;
  final SlotTemplateNotice? notice;

  SlotRangeIssue? get rangeIssue {
    final s = start, e = end;
    if (s == null || e == null) return null;
    return validateSlotRange(
      start: s,
      end: e,
      branchOpen: branch?.openTime,
      branchClose: branch?.closeTime,
    );
  }

  List<GeneratedSlot> get slots {
    final s = start, e = end, p = price;
    if (s == null || e == null || p == null || rangeIssue != null) {
      return const [];
    }
    return generateSlotMatrix(start: s, end: e, price: p);
  }

  /// Request hợp lệ để áp dụng, hoặc `null` nếu còn lỗi cần sửa.
  SlotTemplateRequest? get request {
    final s = start, e = end, p = price;
    if (status != SlotTemplateStatus.ready ||
        s == null ||
        e == null ||
        p == null ||
        p <= 0 ||
        daysOfWeek.isEmpty ||
        rangeIssue != null) {
      return null;
    }
    return SlotTemplateRequest(
      startTime: s,
      endTime: e,
      durationMinutes: standardSlotMinutes,
      price: p,
      daysOfWeek: daysOfWeek.toList()..sort(),
    );
  }

  SlotTemplateState copyWith({
    ClockTime? start,
    ClockTime? end,
    int? price,
    bool clearPrice = false,
    Set<int>? daysOfWeek,
    bool? applying,
    SlotTemplateNotice? notice,
  }) => SlotTemplateState(
    status: status,
    court: court,
    branch: branch,
    start: start ?? this.start,
    end: end ?? this.end,
    price: clearPrice ? null : price ?? this.price,
    daysOfWeek: daysOfWeek ?? this.daysOfWeek,
    applying: applying ?? this.applying,
    message: message,
    notice: notice,
  );

  @override
  List<Object?> get props => [
    status,
    court,
    branch,
    start,
    end,
    price,
    daysOfWeek,
    applying,
    message,
    notice,
  ];
}
