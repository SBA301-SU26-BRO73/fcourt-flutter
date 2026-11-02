part of 'branch_list_bloc.dart';

enum BranchListStatus { initial, loading, success, failure }

const _keep = Object();

class BranchListState extends Equatable {
  const BranchListState({
    this.status = BranchListStatus.initial,
    this.branches = const [],
    this.message,
  });

  final BranchListStatus status;
  final List<Branch> branches;
  final String? message;

  BranchListState copyWith({
    BranchListStatus? status,
    List<Branch>? branches,
    Object? message = _keep,
  }) => BranchListState(
    status: status ?? this.status,
    branches: branches ?? this.branches,
    message: identical(message, _keep) ? this.message : message as String?,
  );

  @override
  List<Object?> get props => [status, branches, message];
}
