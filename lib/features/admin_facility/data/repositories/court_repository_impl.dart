import '../../../../core/error/remote_call.dart';
import '../../domain/entities/court.dart';
import '../../domain/entities/court_type.dart';
import '../../domain/repositories/court_repository.dart';
import '../datasources/court_type_local_data_source.dart';
import '../datasources/facility_remote_data_source.dart';
import '../models/court_model.dart';
import '../models/json_readers.dart';

class CourtRepositoryImpl implements CourtRepository {
  const CourtRepositoryImpl(this._remote);

  final FacilityRemoteDataSource _remote;

  @override
  Future<List<Court>> getCourts(int branchId) => remoteCall(() async {
    final body = await _remote.getCourts(branchId);
    return readJsonList(body).map(CourtModel.fromJson).toList();
  });

  @override
  Future<Court> getCourt(int id) => remoteCall(
    () async => CourtModel.fromJson(readJsonObject(await _remote.getCourt(id))),
  );

  @override
  Future<Court> createCourt(int branchId, CourtDraft draft) => remoteCall(
    () async => CourtModel.fromJson(
      readJsonObject(
        await _remote.createCourt(branchId, CourtModel.toJson(draft)),
      ),
    ),
  );

  @override
  Future<Court> updateCourt(int id, CourtDraft draft) => remoteCall(
    () async => CourtModel.fromJson(
      readJsonObject(await _remote.updateCourt(id, CourtModel.toJson(draft))),
    ),
  );

  @override
  Future<Court> changeStatus(int id, CourtStatus status) => remoteCall(
    () async => CourtModel.fromJson(
      readJsonObject(
        await _remote.changeCourtStatus(id, CourtModel.statusToJson(status)),
      ),
    ),
  );
}

class CourtTypeRepositoryImpl implements CourtTypeRepository {
  const CourtTypeRepositoryImpl([
    this._local = const CourtTypeLocalDataSource(),
  ]);

  final CourtTypeLocalDataSource _local;

  @override
  Future<List<CourtType>> getCourtTypes() async => _local.getCourtTypes();
}
