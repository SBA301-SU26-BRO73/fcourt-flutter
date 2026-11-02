import '../entities/branch.dart';
import '../repositories/branch_repository.dart';

class GetBranches {
  const GetBranches(this._repository);

  final BranchRepository _repository;

  Future<List<Branch>> call() => _repository.getBranches();
}

class GetBranch {
  const GetBranch(this._repository);

  final BranchRepository _repository;

  Future<Branch> call(int id) => _repository.getBranch(id);
}

/// Tạo mới khi [id] là `null`, ngược lại cập nhật chi nhánh [id].
class SaveBranch {
  const SaveBranch(this._repository);

  final BranchRepository _repository;

  Future<Branch> call(BranchDraft draft, {int? id}) => id == null
      ? _repository.createBranch(draft)
      : _repository.updateBranch(id, draft);
}
