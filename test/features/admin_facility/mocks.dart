import 'package:fcourt/features/admin_facility/domain/entities/branch.dart';
import 'package:fcourt/features/admin_facility/domain/entities/clock_time.dart';
import 'package:fcourt/features/admin_facility/domain/entities/court.dart';
import 'package:fcourt/features/admin_facility/domain/entities/slot_template.dart';
import 'package:fcourt/features/admin_facility/domain/repositories/branch_repository.dart';
import 'package:fcourt/features/admin_facility/domain/repositories/court_repository.dart';
import 'package:fcourt/features/admin_facility/domain/repositories/slot_template_repository.dart';
import 'package:mocktail/mocktail.dart';

import 'fixtures.dart';

class MockBranchRepository extends Mock implements BranchRepository {}

class MockCourtRepository extends Mock implements CourtRepository {}

class MockCourtTypeRepository extends Mock implements CourtTypeRepository {}

class MockSlotTemplateRepository extends Mock
    implements SlotTemplateRepository {}

void registerFacilityFallbacks() {
  registerFallbackValue(sampleBranch().toDraft());
  registerFallbackValue(sampleCourtDraft);
  registerFallbackValue(CourtStatus.active);
  registerFallbackValue(
    const SlotTemplateRequest(
      startTime: ClockTime(6, 0),
      endTime: ClockTime(7, 0),
      price: 1,
    ),
  );
}

BranchDraft draftWith({ClockTime? open, ClockTime? close, String? account}) {
  final d = sampleBranch().toDraft();
  return BranchDraft(
    name: d.name,
    address: d.address,
    city: d.city,
    district: d.district,
    openTime: open ?? d.openTime,
    closeTime: close ?? d.closeTime,
    bankName: d.bankName,
    bankBin: d.bankBin,
    bankAccountNumber: account ?? d.bankAccountNumber,
    bankAccountName: d.bankAccountName,
  );
}
