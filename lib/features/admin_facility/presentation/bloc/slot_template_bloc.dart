import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/branch.dart';
import '../../domain/entities/clock_time.dart';
import '../../domain/entities/court.dart';
import '../../domain/entities/slot_matrix.dart';
import '../../domain/entities/slot_template.dart';
import '../../domain/usecases/apply_slot_template.dart';
import '../../domain/usecases/branch_usecases.dart';
import '../../domain/usecases/court_usecases.dart';

part 'slot_template_event.dart';
part 'slot_template_state.dart';

/// SCRUM-19: cấu hình mẫu khung giờ, xem trước ma trận slot và áp dụng cho sân.
///
/// Bản xem trước được tính ngay trên máy theo cùng quy tắc với backend;
/// việc lưu luôn đi qua `apply-template` của facility-service.
class SlotTemplateBloc extends Bloc<SlotTemplateEvent, SlotTemplateState> {
  SlotTemplateBloc({
    required this.courtId,
    required this._getCourt,
    required this._getBranch,
    required this._applyTemplate,
  }) : super(const SlotTemplateState()) {
    on<SlotTemplateStarted>(_onStarted);
    on<SlotTemplateRangeChanged>(_onRangeChanged);
    on<SlotTemplatePriceChanged>(_onPriceChanged);
    on<SlotTemplateDayToggled>(_onDayToggled);
    on<SlotTemplateApplyRequested>(_onApplyRequested);
  }

  final int courtId;
  final GetCourt _getCourt;
  final GetBranch _getBranch;
  final ApplySlotTemplate _applyTemplate;

  Future<void> _onStarted(
    SlotTemplateStarted event,
    Emitter<SlotTemplateState> emit,
  ) async {
    emit(const SlotTemplateState());
    try {
      final court = await _getCourt(courtId);
      final branch = await _getBranch(court.branchId);
      emit(
        SlotTemplateState(
          status: SlotTemplateStatus.ready,
          court: court,
          branch: branch,
          start: branch.openTime,
          end: branch.closeTime,
          // Sân seed chưa có giá giờ: để trống, chủ sân nhập giá mỗi slot.
          price: court.defaultPricePerHour == null
              ? null
              : defaultSlotPrice(court.defaultPricePerHour!),
        ),
      );
    } on Failure catch (failure) {
      emit(
        SlotTemplateState(
          status: SlotTemplateStatus.loadFailure,
          message: failure.message,
        ),
      );
    }
  }

  void _onRangeChanged(
    SlotTemplateRangeChanged event,
    Emitter<SlotTemplateState> emit,
  ) => emit(
    state.copyWith(
      start: event.start ?? state.start,
      end: event.end ?? state.end,
    ),
  );

  void _onPriceChanged(
    SlotTemplatePriceChanged event,
    Emitter<SlotTemplateState> emit,
  ) =>
      emit(state.copyWith(price: event.price, clearPrice: event.price == null));

  void _onDayToggled(
    SlotTemplateDayToggled event,
    Emitter<SlotTemplateState> emit,
  ) {
    final days = {...state.daysOfWeek};
    if (!days.remove(event.dayOfWeek)) days.add(event.dayOfWeek);
    emit(state.copyWith(daysOfWeek: days));
  }

  Future<void> _onApplyRequested(
    SlotTemplateApplyRequested event,
    Emitter<SlotTemplateState> emit,
  ) async {
    final request = state.request;
    if (request == null || state.applying) return;
    emit(state.copyWith(applying: true));
    try {
      final applied = await _applyTemplate(courtId, request);
      emit(
        state.copyWith(
          applying: false,
          notice: SlotTemplateNotice(
            'Đã áp dụng ${applied.totalSlots} slot cho '
            '${applied.daysOfWeek.length} ngày trong tuần',
          ),
        ),
      );
    } on Failure catch (failure) {
      emit(
        state.copyWith(
          applying: false,
          notice: SlotTemplateNotice(failure.message, isError: true),
        ),
      );
    }
  }
}
