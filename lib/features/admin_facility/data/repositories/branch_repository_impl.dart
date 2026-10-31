import 'facility_failures.dart';
import '../../domain/entities/branch.dart';
import '../../domain/repositories/branch_repository.dart';
import '../datasources/facility_remote_data_source.dart';
import '../models/branch_model.dart';
import '../models/json_readers.dart';

class BranchRepositoryImpl implements BranchRepository {
  const BranchRepositoryImpl(this._remote);

  final FacilityRemoteDataSource _remote;

  @override
  Future<List<Branch>> getBranches() => facilityCall(() async {
    final body = await _remote.getBranches();
    return readJsonList(body).map(BranchModel.fromJson).toList();
  });

  @override
  Future<Branch> getBranch(int id) => facilityCall(
    () async =>
        BranchModel.fromJson(readJsonObject(await _remote.getBranch(id))),
  );

  @override
  Future<Branch> createBranch(BranchDraft draft) => facilityCall(
    () async => BranchModel.fromJson(
      readJsonObject(await _remote.createBranch(BranchModel.toJson(draft))),
    ),
  );

  @override
  Future<Branch> updateBranch(int id, BranchDraft draft) => facilityCall(
    () async => BranchModel.fromJson(
      readJsonObject(await _remote.updateBranch(id, BranchModel.toJson(draft))),
    ),
  );
}
