import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../admin_facility/domain/repositories/branch_repository.dart';
import '../domain/voucher.dart';
import '../domain/voucher_repository.dart';
import 'voucher_state.dart';

class VoucherCubit extends Cubit<VoucherState> {
  VoucherCubit(this.repository, this.branches) : super(const VoucherState());
  final VoucherRepository repository;
  final BranchRepository branches;
  int _revision = 0, _branchRevision = 0;
  String _message(Object error) => error is Failure
      ? error.message
      : 'Không tải được voucher. Vui lòng thử lại.';

  Future<void> initialize() async {
    final revision = ++_revision;
    _branchRevision++;
    emit(const VoucherState());
    try {
      final owned = await branches.getBranches();
      if (isClosed || revision != _revision) return;
      emit(VoucherState(branches: List.unmodifiable(owned), loading: false));
      if (owned.isNotEmpty) await selectBranch(owned.first.id);
    } catch (error) {
      if (!isClosed && revision == _revision)
        emit(VoucherState(loading: false, error: _message(error)));
    }
  }

  Future<void> selectBranch(int id) async {
    if (!state.branches.any((branch) => branch.id == id)) return;
    _branchRevision++;
    emit(VoucherState(branches: state.branches, branchId: id));
    await refresh();
  }

  Future<void> refresh() async {
    final branchId = state.branchId;
    if (branchId == null) return;
    final revision = ++_revision;
    emit(state.copyWith(loading: true, loadingMore: false));
    await _load(revision, branchId, 0);
  }

  Future<void> loadMore() async {
    if (state.loading ||
        state.loadingMore ||
        !state.hasMore ||
        state.branchId == null)
      return;
    emit(state.copyWith(loadingMore: true));
    await _load(_revision, state.branchId!, state.page + 1);
  }

  Future<void> _load(int revision, int branchId, int page) async {
    try {
      final result = await repository.list(branchId, page: page);
      if (isClosed || revision != _revision) return;
      final items = <int, Voucher>{
        if (page > 0)
          for (final row in state.items) row.id: row,
        for (final row in result.items) row.id: row,
      };
      emit(
        state.copyWith(
          items: List.unmodifiable(items.values),
          page: result.page,
          total: result.total,
          hasMore: result.hasMore,
          loading: false,
          loadingMore: false,
        ),
      );
    } catch (error) {
      if (!isClosed && revision == _revision)
        emit(
          state.copyWith(
            loading: false,
            loadingMore: false,
            error: _message(error),
          ),
        );
    }
  }

  Future<void> setEnabled(Voucher row, bool enabled) async {
    if (state.branchId != row.branchId || state.busyIds.contains(row.id))
      return;
    final branchRevision = _branchRevision;
    emit(state.copyWith(busyIds: Set.unmodifiable({...state.busyIds, row.id})));
    try {
      final saved = await repository.setEnabled(row.id, row.branchId, enabled);
      if (isClosed || branchRevision != _branchRevision) return;
      _revision++;
      emit(
        state.copyWith(
          items: List.unmodifiable(
            state.items.map((item) => item.id == saved.id ? saved : item),
          ),
          loading: false,
          loadingMore: false,
        ),
      );
      await refresh();
    } catch (error) {
      if (!isClosed && branchRevision == _branchRevision)
        emit(state.copyWith(error: _message(error)));
    } finally {
      if (!isClosed && branchRevision == _branchRevision) {
        emit(
          state.copyWith(
            busyIds: Set.unmodifiable({...state.busyIds}..remove(row.id)),
            error: state.error,
          ),
        );
      }
    }
  }

  @override
  Future<void> close() {
    _revision++;
    _branchRevision++;
    return super.close();
  }
}
