import '../entities/slot_template.dart';

abstract class SlotTemplateRepository {
  /// Thay toàn bộ mẫu khung giờ đang hoạt động của sân cho các ngày được chọn.
  Future<AppliedTemplate> applyTemplate(
    int courtId,
    SlotTemplateRequest request,
  );
}
