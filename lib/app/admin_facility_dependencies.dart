import '../core/config/app_config.dart';
import '../core/network/dio_client.dart';
import '../core/storage/token_storage.dart';
import '../features/admin_dashboard/data/datasources/reporting_remote_data_source.dart';
import '../features/admin_dashboard/data/repositories/dashboard_repository_impl.dart';
import '../features/admin_dashboard/domain/repositories/dashboard_repository.dart';
import '../features/admin_facility/data/datasources/facility_remote_data_source.dart';
import '../features/admin_facility/data/repositories/branch_repository_impl.dart';
import '../features/admin_facility/data/repositories/court_repository_impl.dart';
import '../features/admin_facility/data/repositories/slot_template_repository_impl.dart';
import '../features/admin_facility/domain/repositories/branch_repository.dart';
import '../features/admin_facility/domain/repositories/court_repository.dart';
import '../features/admin_facility/domain/repositories/slot_template_repository.dart';

/// Repository cho các màn hình chủ sân: chi nhánh, sân, mẫu khung giờ
/// (facility-service) và dashboard (reporting-service).
class AdminFacilityDependencies {
  const AdminFacilityDependencies({
    required this.branchRepository,
    required this.courtRepository,
    required this.courtTypeRepository,
    required this.slotTemplateRepository,
    required this.dashboardRepository,
  });

  final BranchRepository branchRepository;
  final CourtRepository courtRepository;
  final CourtTypeRepository courtTypeRepository;
  final SlotTemplateRepository slotTemplateRepository;
  final DashboardRepository dashboardRepository;

  /// Mỗi service có Dio riêng theo `FACILITY_BASE_URL` / `REPORTING_BASE_URL`
  /// (mặc định `API_BASE_URL`), cùng chung TokenStorage để gắn Bearer token.
  factory AdminFacilityDependencies.create(
    AppConfig config,
    TokenStorage tokenStorage,
  ) {
    final facility = FacilityRemoteDataSource(
      createDio(config, tokenStorage, baseUrl: config.facilityUrl),
    );
    final reporting = ReportingRemoteDataSource(
      createDio(config, tokenStorage, baseUrl: config.reportingUrl),
    );
    return AdminFacilityDependencies(
      branchRepository: BranchRepositoryImpl(facility),
      courtRepository: CourtRepositoryImpl(facility),
      courtTypeRepository: const CourtTypeRepositoryImpl(),
      slotTemplateRepository: SlotTemplateRepositoryImpl(facility),
      dashboardRepository: DashboardRepositoryImpl(reporting),
    );
  }
}
