part of 'slot_template_bloc.dart';

sealed class SlotTemplateEvent extends Equatable {
  const SlotTemplateEvent();

  @override
  List<Object?> get props => [];
}

/// Tải sân và chi nhánh (giờ mở/đóng cửa, giá mặc định).
class SlotTemplateStarted extends SlotTemplateEvent {
  const SlotTemplateStarted();
}

class SlotTemplateRangeChanged extends SlotTemplateEvent {
  const SlotTemplateRangeChanged({this.start, this.end});

  final ClockTime? start;
  final ClockTime? end;

  @override
  List<Object?> get props => [start, end];
}

/// [price] `null` khi ô giá đang trống/không hợp lệ.
class SlotTemplatePriceChanged extends SlotTemplateEvent {
  const SlotTemplatePriceChanged(this.price);

  final int? price;

  @override
  List<Object?> get props => [price];
}

class SlotTemplateDayToggled extends SlotTemplateEvent {
  const SlotTemplateDayToggled(this.dayOfWeek);

  final int dayOfWeek;

  @override
  List<Object?> get props => [dayOfWeek];
}

/// Gửi `apply-template` (sau khi người dùng xác nhận).
class SlotTemplateApplyRequested extends SlotTemplateEvent {
  const SlotTemplateApplyRequested();
}
