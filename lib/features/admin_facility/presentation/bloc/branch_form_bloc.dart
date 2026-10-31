import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/branch.dart';
import '../../domain/entities/branch_rules.dart';
import '../../domain/usecases/branch_usecases.dart';

part 'branch_form_event.dart';
part 'branch_form_state.dart';

/// Tạo chi nhánh (branchId = null) hoặc sửa chi nhánh có sẵn.
class BranchFormBloc extends Bloc<BranchFormEvent, BranchFormState> {
  BranchFormBloc({
    required this._getBranch,
    required this._saveBranch,
    this.branchId,
  }) : super(
         BranchFormState(
           status: branchId == null
               ? BranchFormStatus.ready
               : BranchFormStatus.loading,
         ),
       ) {
    on<BranchFormStarted>(_onStarted);
    on<BranchFormSubmitted>(_onSubmitted);
  }

  final GetBranch _getBranch;
  final SaveBranch _saveBranch;
  final int? branchId;

  bool get isEditing => branchId != null;

  Future<void> _onStarted(
    BranchFormStarted event,
    Emitter<BranchFormState> emit,
  ) async {
    final id = branchId;
    if (id == null) return;
    emit(const BranchFormState(status: BranchFormStatus.loading));
    try {
      final branch = await _getBranch(id);
      emit(BranchFormState(status: BranchFormStatus.ready, initial: branch));
    } on Failure catch (failure) {
      emit(
        BranchFormState(
          status: BranchFormStatus.loadFailure,
          message: failure.message,
        ),
      );
    }
  }

  Future<void> _onSubmitted(
    BranchFormSubmitted event,
    Emitter<BranchFormState> emit,
  ) async {
    if (state.status == BranchFormStatus.submitting) return;
    // Chặn lần cuối ở tầng nghiệp vụ, phòng khi UI bỏ sót validator.
    final draft = event.draft;
    final invalid =
        BranchRules.timeRange(draft.openTime, draft.closeTime) ??
        BranchRules.bankBin(draft.bankBin) ??
        BranchRules.accountNumber(draft.bankAccountNumber);
    if (invalid != null) {
      emit(state.copyWith(status: BranchFormStatus.failure, message: invalid));
      return;
    }
    emit(state.copyWith(status: BranchFormStatus.submitting));
    try {
      final saved = await _saveBranch(draft, id: branchId);
      emit(state.copyWith(status: BranchFormStatus.success, saved: saved));
    } on Failure catch (failure) {
      emit(
        state.copyWith(
          status: BranchFormStatus.failure,
          message: failure.message,
        ),
      );
    }
  }
}
