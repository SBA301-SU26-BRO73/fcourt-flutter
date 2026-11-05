import '../core/config/app_config.dart';
import '../core/network/dio_client.dart';
import '../core/storage/token_storage.dart';
import '../features/admin_dashboard/data/datasources/reporting_remote_data_source.dart';
import '../features/admin_dashboard/data/repositories/analytics_repository_impl.dart';
import '../features/admin_dashboard/data/repositories/dashboard_repository_impl.dart';
import '../features/admin_dashboard/domain/repositories/analytics_repository.dart';
import '../features/admin_dashboard/domain/repositories/dashboard_repository.dart';
import '../features/admin_facility/data/datasources/facility_remote_data_source.dart';
import '../features/admin_facility/data/repositories/branch_repository_impl.dart';
import '../features/admin_facility/data/repositories/catalog_court_type_repository.dart';
import '../features/admin_facility/data/repositories/court_repository_impl.dart';
import '../features/admin_facility/data/repositories/slot_template_repository_impl.dart';
import '../features/admin_facility/domain/repositories/branch_repository.dart';
import '../features/admin_facility/domain/repositories/court_repository.dart';
import '../features/admin_facility/domain/repositories/slot_template_repository.dart';
import '../features/catalog/domain/repositories/catalog_repository.dart';

/// Repository cho các màn hình chủ sân: chi nhánh, sân, mẫu khung giờ
/// (facility-service) và dashboard (reporting-service).
class AdminFacilityDependencies {
  const AdminFacilityDependencies({
    required this.branchRepository,
    required this.courtRepository,
    required this.courtTypeRepository,
    required this.slotTemplateRepository,
    required this.dashboardRepository,
    required this.analyticsRepository,
  });

  final BranchRepository branchRepository;
  final CourtRepository courtRepository;
  final CourtTypeRepository courtTypeRepository;
  final SlotTemplateRepository slotTemplateRepository;
  final DashboardRepository dashboardRepository;
  final AnalyticsRepository analyticsRepository;

  /// Mỗi service có Dio riêng theo `FACILITY_BASE_URL` / `REPORTING_BASE_URL`
  /// (mặc định `API_BASE_URL`), cùng chung TokenStorage để gắn Bearer token.
  factory AdminFacilityDependencies.create(
    AppConfig config,
    TokenStorage tokenStorage,
    CatalogRepository catalogRepository, {
    void Function()? onSessionExpired,
  }) {
    final facility = FacilityRemoteDataSource(
      createDio(
        config,
        tokenStorage,
        baseUrl: config.facilityUrl,
        onSessionExpired: onSessionExpired,
      ),
    );
    final reporting = ReportingRemoteDataSource(
      createDio(
        config,
        tokenStorage,
        baseUrl: config.reportingUrl,
        onSessionExpired: onSessionExpired,
      ),
    );
    return AdminFacilityDependencies(
      branchRepository: BranchRepositoryImpl(facility),
      courtRepository: CourtRepositoryImpl(facility),
      courtTypeRepository: CatalogCourtTypeRepository(catalogRepository),
      slotTemplateRepository: SlotTemplateRepositoryImpl(facility),
      dashboardRepository: DashboardRepositoryImpl(reporting),
      analyticsRepository: AnalyticsRepositoryImpl(reporting),
    );
  }
}
