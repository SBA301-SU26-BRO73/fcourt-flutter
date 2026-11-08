part of 'bulk_apply_template_bloc.dart';

sealed class BulkApplyTemplateEvent extends Equatable {
  const BulkApplyTemplateEvent();

  @override
  List<Object?> get props => [];
}

class BulkCourtToggled extends BulkApplyTemplateEvent {
  const BulkCourtToggled(this.courtId);

  final int courtId;

  @override
  List<Object?> get props => [courtId];
}

/// Chọn tất cả sân; nếu đã chọn hết thì bỏ chọn hết.
class BulkSelectAllToggled extends BulkApplyTemplateEvent {
  const BulkSelectAllToggled();
}

class BulkRangeChanged extends BulkApplyTemplateEvent {
  const BulkRangeChanged({this.start, this.end});

  final ClockTime? start;
  final ClockTime? end;

  @override
  List<Object?> get props => [start, end];
}

/// [price] `null` khi ô giá trống: backend dùng giá giờ của từng sân.
class BulkPriceChanged extends BulkApplyTemplateEvent {
  const BulkPriceChanged(this.price);

  final int? price;

  @override
  List<Object?> get props => [price];
}

class BulkDayToggled extends BulkApplyTemplateEvent {
  const BulkDayToggled(this.dayOfWeek);

  final int dayOfWeek;

  @override
  List<Object?> get props => [dayOfWeek];
}

/// Gọi `bulk-apply-template/preview`.
class BulkPreviewRequested extends BulkApplyTemplateEvent {
  const BulkPreviewRequested();
}

/// Từ bước xem trước quay lại chỉnh cấu hình.
class BulkBackToEditing extends BulkApplyTemplateEvent {
  const BulkBackToEditing();
}

/// Gửi `bulk-apply-template` (sau bước xác nhận).
class BulkApplyRequested extends BulkApplyTemplateEvent {
  const BulkApplyRequested();
}
