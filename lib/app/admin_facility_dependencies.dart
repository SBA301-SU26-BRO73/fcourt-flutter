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

import 'package:dio/dio.dart';

import '../src/features/branch_gallery/data/branch_image_repository_impl.dart';
import '../src/features/branch_gallery/data/device_branch_image_picker.dart';
import '../src/features/branch_gallery/domain/branch_image.dart';

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
    this.branchImageRepository,
    this.branchImagePicker,
  });

  final BranchRepository branchRepository;
  final CourtRepository courtRepository;
  final CourtTypeRepository courtTypeRepository;
  final SlotTemplateRepository slotTemplateRepository;
  final DashboardRepository dashboardRepository;
  final AnalyticsRepository analyticsRepository;

  /// Ảnh chi nhánh (SCRUM-47/48): chủ sân thêm/xóa, khách chỉ đọc qua endpoint công khai.
  final BranchImageRepository? branchImageRepository;
  final BranchImagePicker? branchImagePicker;

  /// Mỗi service có Dio riêng theo `FACILITY_BASE_URL` / `REPORTING_BASE_URL`
  /// (mặc định `API_BASE_URL`), cùng chung TokenStorage để gắn Bearer token.
  factory AdminFacilityDependencies.create(
    AppConfig config,
    TokenStorage tokenStorage,
    CatalogRepository catalogRepository, {
    void Function()? onSessionExpired,
  }) {
    final facilityDio = createDio(
      config,
      tokenStorage,
      baseUrl: config.facilityUrl,
      onSessionExpired: onSessionExpired,
    );
    final facility = FacilityRemoteDataSource(facilityDio);
    final publicFacilityDio = Dio(
      BaseOptions(
        baseUrl: config.facilityUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {'Accept': 'application/json'},
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
      branchImageRepository: BranchImageRepositoryImpl(
        publicDio: publicFacilityDio,
        adminDio: facilityDio,
      ),
      branchImagePicker: DeviceBranchImagePicker(),
    );
  }
}
