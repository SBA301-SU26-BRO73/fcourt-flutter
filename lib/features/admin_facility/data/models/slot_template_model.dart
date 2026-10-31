import '../../domain/entities/slot_template.dart';
import 'json_readers.dart';

/// Chuyển đổi ApplyTemplateRequest / response `apply-template`.
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
}
