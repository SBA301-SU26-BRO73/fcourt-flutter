import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/court.dart';
import '../../domain/entities/pricing_rule.dart';
import '../../domain/entities/pricing_rules.dart';
import '../../domain/usecases/court_usecases.dart';
import '../../domain/usecases/pricing_usecases.dart';

part 'pricing_rule_event.dart';
part 'pricing_rule_state.dart';

/// SCRUM-81/83: cấu hình giá cao điểm/thấp điểm và giá cuối tuần của một sân.
///
/// Kiểm tra giờ/chồng lấn được làm ngay trên máy theo cùng quy tắc với backend
/// để báo lỗi sớm; mọi thay đổi vẫn đi qua `pricing-rules` của facility-service
/// và danh sách luôn được nạp lại từ máy chủ sau khi lưu.
class PricingRuleBloc extends Bloc<PricingRuleEvent, PricingRuleState> {
  PricingRuleBloc({
    required this.courtId,
    required this._getCourt,
    required this._getRules,
    required this._saveRule,
    required this._deleteRule,
    required this._copyToWeekend,
  }) : super(const PricingRuleState()) {
    on<PricingRuleStarted>(_onStarted);
    on<PricingRuleSaved>(_onSaved);
    on<PricingRuleDeleted>(_onDeleted);
    on<PricingRuleCopyToWeekendRequested>(_onCopy);
  }

  final int courtId;
  final GetCourt _getCourt;
  final GetPricingRules _getRules;
  final SavePricingRule _saveRule;
  final DeletePricingRule _deleteRule;
  final CopyWeekdayToWeekend _copyToWeekend;

  Future<void> _onStarted(
    PricingRuleStarted event,
    Emitter<PricingRuleState> emit,
  ) async {
    emit(const PricingRuleState());
    try {
      final court = await _getCourt(courtId);
      final rules = await _getRules(courtId);
      emit(
        PricingRuleState(
          status: PricingRuleStatus.ready,
          court: court,
          rules: rules,
        ),
      );
    } on Failure catch (failure) {
      emit(
        PricingRuleState(
          status: PricingRuleStatus.loadFailure,
          message: failure.message,
        ),
      );
    }
  }

  Future<void> _onSaved(
    PricingRuleSaved event,
    Emitter<PricingRuleState> emit,
  ) async {
    if (state.busy) return;
    final issue = validatePricingDraft(event.draft);
    if (issue != null) {
      emit(state.copyWith(notice: PricingNotice(issue.message, isError: true)));
      return;
    }
    if (findPricingConflict(
          state.rules,
          event.draft,
          exceptId: event.ruleId,
        ) !=
        null) {
      emit(
        state.copyWith(
          notice: PricingNotice(
            'Khung giờ trùng với một quy tắc giá khác trong cùng nhóm ngày',
            isError: true,
          ),
        ),
      );
      return;
    }
    await _mutate(
      emit,
      () => _saveRule(courtId, event.draft, ruleId: event.ruleId),
      event.ruleId == null ? 'Đã thêm khung giá' : 'Đã cập nhật khung giá',
    );
  }

  Future<void> _onDeleted(
    PricingRuleDeleted event,
    Emitter<PricingRuleState> emit,
  ) async {
    if (state.busy) return;
    await _mutate(
      emit,
      () => _deleteRule(courtId, event.ruleId),
      'Đã xóa khung giá',
    );
  }

  Future<void> _onCopy(
    PricingRuleCopyToWeekendRequested event,
    Emitter<PricingRuleState> emit,
  ) async {
    if (state.busy) return;
    await _mutate(
      emit,
      () => _copyToWeekend(courtId, multiplier: event.multiplier),
      'Đã sao chép cấu hình sang cuối tuần',
    );
  }

  /// Chạy một thay đổi rồi nạp lại danh sách để UI luôn khớp máy chủ.
  Future<void> _mutate(
    Emitter<PricingRuleState> emit,
    Future<Object?> Function() action,
    String successMessage,
  ) async {
    emit(state.copyWith(busy: true));
    try {
      await action();
      final rules = await _getRules(courtId);
      emit(
        state.copyWith(
          busy: false,
          rules: rules,
          notice: PricingNotice(successMessage),
        ),
      );
    } on Failure catch (failure) {
      emit(
        state.copyWith(
          busy: false,
          notice: PricingNotice(failure.message, isError: true),
        ),
      );
    }
  }
}
