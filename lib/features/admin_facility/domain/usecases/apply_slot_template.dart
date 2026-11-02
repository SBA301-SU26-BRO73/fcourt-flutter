import '../entities/slot_template.dart';
import '../repositories/slot_template_repository.dart';

class ApplySlotTemplate {
  const ApplySlotTemplate(this._repository);

  final SlotTemplateRepository _repository;

  Future<AppliedTemplate> call(int courtId, SlotTemplateRequest request) =>
      _repository.applyTemplate(courtId, request);
}
