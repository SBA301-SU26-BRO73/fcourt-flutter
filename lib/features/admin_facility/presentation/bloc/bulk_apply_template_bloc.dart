import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/clock_time.dart';
import '../../domain/entities/court.dart';
import '../../domain/entities/slot_matrix.dart';
import '../../domain/entities/slot_template.dart';
import '../../domain/usecases/apply_slot_template.dart';

part 'bulk_apply_template_event.dart';
part 'bulk_apply_template_state.dart';

/// SCRUM-52: chọn nhiều sân, cấu hình mẫu, xem trước tổng hợp rồi áp dụng một
/// lần qua `bulk-apply-template` (SCRUM-51: tất cả hoặc không sân nào).
class BulkApplyTemplateBloc
    extends Bloc<BulkApplyTemplateEvent, BulkApplyTemplateState> {
  BulkApplyTemplateBloc({
    required List<Court> courts,
    required ClockTime start,
    required ClockTime end,
    ClockTime? branchOpen,
    ClockTime? branchClose,
    required this._previewBulk,
    required this._applyBulk,
  }) : super(
         BulkApplyTemplateState(
           courts: List.unmodifiable(courts),
           start: start,
           end: end,
           branchOpen: branchOpen,
           branchClose: branchClose,
         ),
       ) {
    on<BulkCourtToggled>(_onCourtToggled);
    on<BulkSelectAllToggled>(_onSelectAllToggled);
    on<BulkRangeChanged>(_onRangeChanged);
    on<BulkPriceChanged>(_onPriceChanged);
    on<BulkDayToggled>(_onDayToggled);
    on<BulkPreviewRequested>(_onPreviewRequested);
    on<BulkBackToEditing>(_onBackToEditing);
    on<BulkApplyRequested>(_onApplyRequested);
  }

  final PreviewBulkSlotTemplate _previewBulk;
  final ApplyBulkSlotTemplate _applyBulk;

  // Cấu hình chỉ sửa được ở bước chỉnh sửa, không khi đang gọi API.
  bool get _locked => state.status != BulkApplyStatus.editing;

  void _onCourtToggled(
    BulkCourtToggled event,
    Emitter<BulkApplyTemplateState> emit,
  ) {
    if (_locked || !state.courts.any((c) => c.id == event.courtId)) return;
    final ids = {...state.selectedIds};
    if (!ids.remove(event.courtId)) ids.add(event.courtId);
    emit(state.copyWith(selectedIds: ids));
  }

  void _onSelectAllToggled(
    BulkSelectAllToggled event,
    Emitter<BulkApplyTemplateState> emit,
  ) {
    if (_locked) return;
    emit(
      state.copyWith(
        selectedIds: state.allSelected
            ? <int>{}
            : {for (final court in state.courts) court.id},
      ),
    );
  }

  void _onRangeChanged(
    BulkRangeChanged event,
    Emitter<BulkApplyTemplateState> emit,
  ) {
    if (_locked) return;
    emit(state.copyWith(start: event.start, end: event.end));
  }

  void _onPriceChanged(
    BulkPriceChanged event,
    Emitter<BulkApplyTemplateState> emit,
  ) {
    if (_locked) return;
    emit(state.copyWith(price: event.price, clearPrice: event.price == null));
  }

  void _onDayToggled(
    BulkDayToggled event,
    Emitter<BulkApplyTemplateState> emit,
  ) {
    if (_locked) return;
    final days = {...state.daysOfWeek};
    if (!days.remove(event.dayOfWeek)) days.add(event.dayOfWeek);
    emit(state.copyWith(daysOfWeek: days));
  }

  Future<void> _onPreviewRequested(
    BulkPreviewRequested event,
    Emitter<BulkApplyTemplateState> emit,
  ) async {
    final request = state.request;
    if (request == null || _locked) return;
    emit(state.copyWith(status: BulkApplyStatus.previewing));
    try {
      final preview = await _previewBulk(request);
      emit(state.copyWith(status: BulkApplyStatus.preview, preview: preview));
    } on Failure catch (failure) {
      emit(
        state.copyWith(status: BulkApplyStatus.editing, error: failure.message),
      );
    }
  }

  void _onBackToEditing(
    BulkBackToEditing event,
    Emitter<BulkApplyTemplateState> emit,
  ) {
    if (state.status != BulkApplyStatus.preview) return;
    emit(state.copyWith(status: BulkApplyStatus.editing));
  }

  Future<void> _onApplyRequested(
    BulkApplyRequested event,
    Emitter<BulkApplyTemplateState> emit,
  ) async {
    final request = state.request;
    final preview = state.preview;
    // Chỉ áp dụng sau khi đã xem trước và không còn xung đột.
    if (state.status != BulkApplyStatus.preview ||
        request == null ||
        preview == null ||
        preview.hasConflicts) {
      return;
    }
    emit(state.copyWith(status: BulkApplyStatus.applying));
    try {
      final applied = await _applyBulk(request);
      emit(state.copyWith(status: BulkApplyStatus.done, applied: applied));
    } on Failure catch (failure) {
      // Backend đã rollback: quay lại bước chỉnh sửa để xem trước lại.
      emit(
        state.copyWith(status: BulkApplyStatus.editing, error: failure.message),
      );
    }
  }
}
