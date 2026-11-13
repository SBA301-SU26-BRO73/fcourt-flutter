import 'facility_failures.dart';
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
  ) => facilityCall(
    () async => SlotTemplateModel.appliedFromJson(
      readJsonObject(
        await _remote.applyTemplate(
          courtId,
          SlotTemplateModel.requestToJson(request),
        ),
      ),
    ),
  );

  @override
  Future<BulkPreview> previewBulk(BulkSlotTemplateRequest request) =>
      facilityCall(
        () async => SlotTemplateModel.bulkPreviewFromJson(
          readJsonObject(
            await _remote.previewBulkTemplate(
              SlotTemplateModel.bulkRequestToJson(request),
            ),
          ),
        ),
      );

  @override
  Future<BulkApplied> applyBulk(BulkSlotTemplateRequest request) =>
      facilityCall(
        () async => SlotTemplateModel.bulkAppliedFromJson(
          readJsonObject(
            await _remote.applyBulkTemplate(
              SlotTemplateModel.bulkRequestToJson(request),
            ),
          ),
        ),
      );
}
