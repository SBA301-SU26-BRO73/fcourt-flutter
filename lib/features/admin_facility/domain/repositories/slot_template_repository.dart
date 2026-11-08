import '../entities/slot_template.dart';

abstract class SlotTemplateRepository {
  /// Thay toàn bộ mẫu khung giờ đang hoạt động của sân cho các ngày được chọn.
  Future<AppliedTemplate> applyTemplate(
    int courtId,
    SlotTemplateRequest request,
  );

  /// Xem trước (không ghi dữ liệu) mẫu áp dụng cho nhiều sân.
  Future<BulkPreview> previewBulk(BulkSlotTemplateRequest request);

  /// Áp dụng mẫu cho nhiều sân trong một transaction: lỗi thì không sân nào đổi.
  Future<BulkApplied> applyBulk(BulkSlotTemplateRequest request);
}
