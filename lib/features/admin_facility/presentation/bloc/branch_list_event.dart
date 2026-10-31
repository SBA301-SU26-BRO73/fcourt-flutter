part of 'branch_list_bloc.dart';

sealed class BranchListEvent extends Equatable {
  const BranchListEvent();

  @override
  List<Object?> get props => [];
}

/// Tải (hoặc tải lại) danh sách chi nhánh.
class BranchListRequested extends BranchListEvent {
  const BranchListRequested();
}
