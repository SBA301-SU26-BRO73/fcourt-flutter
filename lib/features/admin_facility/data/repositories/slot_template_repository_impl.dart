import '../../../../core/error/remote_call.dart';
import '../../domain/entities/slot_template.dart';
import '../../domain/repositories/slot_template_repository.dart';
import '../datasources/facility_remote_data_source.dart';
import '../models/json_readers.dart';
import '../models/slot_template_model.dart';

class SlotTemplateRepositoryImpl implements SlotTemplateRepository {
  const SlotTemplateRepositoryImpl(this._remote);

  final FacilityRemoteDataSource _remote;

  @override
  Future<AppliedTemplate> applyTemplate(
    int courtId,
    SlotTemplateRequest request,
  ) => remoteCall(
    () async => SlotTemplateModel.appliedFromJson(
      readJsonObject(
        await _remote.applyTemplate(
          courtId,
          SlotTemplateModel.requestToJson(request),
        ),
      ),
    ),
  );
}
