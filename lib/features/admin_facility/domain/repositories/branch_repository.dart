import '../entities/branch.dart';

/// Chi nhánh của chủ sân đang đăng nhập. Lỗi được ném dưới dạng `Failure`.
abstract class BranchRepository {
  Future<List<Branch>> getBranches();
  Future<Branch> getBranch(int id);
  Future<Branch> createBranch(BranchDraft draft);
  Future<Branch> updateBranch(int id, BranchDraft draft);
}
