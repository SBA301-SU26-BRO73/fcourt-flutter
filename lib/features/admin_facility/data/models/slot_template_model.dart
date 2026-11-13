import '../../domain/entities/slot_matrix.dart';
import '../../domain/entities/slot_template.dart';
import 'json_readers.dart';

/// Chuyển đổi ApplyTemplateRequest / response `apply-template` và bulk apply.
class SlotTemplateModel {
  const SlotTemplateModel._();

  static Map<String, dynamic> requestToJson(SlotTemplateRequest request) => {
    'startTime': request.startTime.format(),
    'endTime': request.endTime.format(),
    'durationMinutes': request.durationMinutes,
    'price': request.price,
    'daysOfWeek': request.daysOfWeek,
  };

  static AppliedTemplate appliedFromJson(Map<String, dynamic> json) {
    final days = json['daysOfWeek'];
    if (days is! List || days.any((d) => d is! int)) {
      throw FormatException('daysOfWeek không hợp lệ', days);
    }
    return AppliedTemplate(
      courtId: json.readInt('courtId'),
      daysOfWeek: List<int>.unmodifiable(days.cast<int>()),
      totalSlots: json.readInt('totalSlots'),
    );
  }

  /// BulkApplyRequest: `price` chỉ gửi khi người dùng nhập.
  static Map<String, dynamic> bulkRequestToJson(
    BulkSlotTemplateRequest request,
  ) => {
    'courtIds': request.courtIds,
    'template': {
      'startTime': request.startTime.format(),
      'endTime': request.endTime.format(),
      'durationMinutes': standardSlotMinutes,
      if (request.price != null) 'price': request.price,
      'daysOfWeek': request.daysOfWeek,
    },
  };

  static BulkPreview bulkPreviewFromJson(Map<String, dynamic> json) {
    final courts = json['courts'];
    if (courts is! List) throw FormatException('courts không hợp lệ', courts);
    return BulkPreview(
      courts: List.unmodifiable([
        for (final court in courts) _previewCourt(readJsonObject(court)),
      ]),
      totalSlots: json.readInt('totalSlots'),
      hasConflicts: json['hasConflicts'] == true,
    );
  }

  static BulkApplied bulkAppliedFromJson(Map<String, dynamic> json) {
    final courts = json['courts'];
    if (courts is! List) throw FormatException('courts không hợp lệ', courts);
    return BulkApplied(
      courtCount: courts.length,
      totalSlots: json.readInt('totalSlots'),
    );
  }

  static BulkPreviewCourt _previewCourt(Map<String, dynamic> json) {
    final days = json['daysOfWeek'];
    final slots = json['slots'];
    if (days is! List || days.any((d) => d is! int)) {
      throw FormatException('daysOfWeek không hợp lệ', days);
    }
    if (slots is! List) throw FormatException('slots không hợp lệ', slots);
    return BulkPreviewCourt(
      courtId: json.readInt('courtId'),
      courtName: json.readString('courtName'),
      daysOfWeek: List<int>.unmodifiable(days.cast<int>()),
      slots: List.unmodifiable([
        for (final slot in slots) _slot(readJsonObject(slot)),
      ]),
      totalSlots: json.readInt('totalSlots'),
      conflict: json.readStringOrNull('conflict'),
    );
  }

  static GeneratedSlot _slot(Map<String, dynamic> json) => GeneratedSlot(
    startTime: json.readTime('startTime'),
    endTime: json.readTime('endTime'),
    price: json.readMoney('price'),
  );
}
