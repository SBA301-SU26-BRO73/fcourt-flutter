import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/branch.dart';
import '../../domain/usecases/branch_usecases.dart';

part 'branch_list_event.dart';
part 'branch_list_state.dart';

class BranchListBloc extends Bloc<BranchListEvent, BranchListState> {
  BranchListBloc(this._getBranches) : super(const BranchListState()) {
    on<BranchListRequested>(_onRequested);
  }

  final GetBranches _getBranches;

  Future<void> _onRequested(
    BranchListRequested event,
    Emitter<BranchListState> emit,
  ) async {
    // Giữ danh sách cũ khi tải lại để không nháy màn hình.
    emit(state.copyWith(status: BranchListStatus.loading, message: null));
    try {
      final branches = await _getBranches();
      emit(
        BranchListState(status: BranchListStatus.success, branches: branches),
      );
    } on Failure catch (failure) {
      emit(
        state.copyWith(
          status: BranchListStatus.failure,
          message: failure.message,
        ),
      );
    }
  }
}
