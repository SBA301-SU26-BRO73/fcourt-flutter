import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../domain/staff.dart';

class StaffState {
  const StaffState({
    this.branches = const [],
    this.members = const [],
    this.branchId,
    this.loading = false,
    this.hasMore = false,
    this.error,
  });
  final List<StaffBranch> branches;
  final List<StaffMember> members;
  final int? branchId;
  final bool loading;
  final bool hasMore;
  final String? error;
}

class StaffCubit extends Cubit<StaffState> {
  StaffCubit(this.repository) : super(const StaffState());
  final StaffRepository repository;
  int _request = 0;

  Future<void> initialize() async {
    emit(const StaffState(loading: true));
    try {
      final branches = await repository.branches();
      if (isClosed) return;
      emit(StaffState(branches: branches));
      if (branches.isNotEmpty) await load(branches.first.id);
    } on Failure catch (e) {
      if (!isClosed) emit(StaffState(error: e.message));
    }
  }

  Future<void> load(int branch, {bool more = false}) async {
    if (more && (state.loading || !state.hasMore)) return;
    final request = ++_request;
    final previous = more ? state.members : <StaffMember>[];
    final branches = state.branches;
    emit(
      StaffState(
        branches: branches,
        members: previous,
        branchId: branch,
        loading: true,
        hasMore: state.hasMore,
      ),
    );
    try {
      final rows = await repository.list(branch, offset: previous.length);
      if (isClosed || request != _request) return;
      emit(
        StaffState(
          branches: branches,
          members: [...previous, ...rows],
          branchId: branch,
          hasMore: rows.length == 50,
        ),
      );
    } on Failure catch (e) {
      if (!isClosed && request == _request) {
        emit(
          StaffState(
            branches: branches,
            members: previous,
            branchId: branch,
            error: e.message,
            hasMore: more,
          ),
        );
      }
    }
  }
}
