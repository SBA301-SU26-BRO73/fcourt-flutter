import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'fc_route.dart';

import '../features/admin_dashboard/domain/usecases/analytics_usecases.dart';
import '../features/admin_dashboard/domain/usecases/get_dashboard_stats.dart';
import '../features/admin_dashboard/presentation/bloc/analytics_bloc.dart';
import '../features/admin_dashboard/presentation/bloc/dashboard_bloc.dart';
import '../features/admin_dashboard/presentation/pages/analytics_screen.dart';
import '../features/admin_dashboard/presentation/pages/admin_dashboard_screen.dart';
import '../features/admin_facility/domain/entities/branch.dart';
import '../features/admin_facility/domain/entities/court.dart';
import '../features/admin_facility/domain/usecases/apply_slot_template.dart';
import '../features/admin_facility/domain/usecases/branch_usecases.dart';
import '../features/admin_facility/domain/usecases/court_usecases.dart';
import '../features/admin_facility/domain/usecases/lock_usecases.dart';
import '../features/admin_facility/domain/usecases/pricing_usecases.dart';
import '../features/admin_facility/presentation/bloc/branch_form_bloc.dart';
import '../features/admin_facility/presentation/bloc/branch_list_bloc.dart';
import '../features/admin_facility/presentation/bloc/bulk_apply_template_bloc.dart';
import '../features/admin_facility/presentation/bloc/court_calendar_bloc.dart';
import '../features/admin_facility/presentation/bloc/court_form_bloc.dart';
import '../features/admin_facility/presentation/bloc/court_list_bloc.dart';
import '../features/admin_facility/presentation/bloc/out_of_service_bloc.dart';
import '../features/admin_facility/presentation/bloc/pricing_rule_bloc.dart';
import '../features/admin_facility/presentation/bloc/slot_template_bloc.dart';
import '../features/admin_facility/presentation/pages/branch_form_screen.dart';
import '../features/admin_facility/presentation/pages/branch_list_screen.dart';
import '../features/admin_facility/presentation/pages/court_calendar_screen.dart';
import '../features/admin_facility/presentation/pages/court_form_screen.dart';
import '../features/admin_facility/presentation/pages/court_list_screen.dart';
import '../features/admin_facility/presentation/pages/out_of_service_management_screen.dart';
import '../features/admin_facility/presentation/pages/pricing_rule_config_screen.dart';
import '../features/admin_facility/presentation/pages/time_slot_template_screen.dart';
import '../features/admin_facility/presentation/widgets/bulk_apply_template_dialog.dart';
import '../src/features/branch_gallery/presentation/admin_branch_images_cubit.dart';
import '../src/features/branch_gallery/presentation/admin_branch_images_screen.dart';
import 'admin_facility_dependencies.dart';

/// Route của chủ sân (SCRUM-13/15/17/19). Trả về danh sách rỗng khi app chưa
/// cấu hình repository (ví dụ trong test của feature khác).
List<RouteBase> adminFacilityRoutes(
  AdminFacilityDependencies? deps, {
  bool hasPayments = false,
  bool hasRefunds = false,
  bool hasTransactions = false,
}) {
  if (deps == null) return const [];
  final branches = deps.branchRepository;
  final courts = deps.courtRepository;
  final images = deps.branchImageRepository;
  final imagePicker = deps.branchImagePicker;
  return [
    if (images != null && imagePicker != null)
      FcRoute(
        path: '/admin/branches/:branchId/images',
        builder: (context, state) => _withId(
          state.pathParameters['branchId'],
          (id) => BlocProvider(
            create: (_) => AdminBranchImagesCubit(
              repository: images,
              picker: imagePicker,
              branchId: id,
            )..load(),
            child: const AdminBranchImagesScreen(),
          ),
        ),
      ),
    FcRoute(
      path: '/admin/dashboard',
      builder: (context, state) => BlocProvider(
        create: (_) => DashboardBloc(
          getBranches: GetBranches(branches),
          getStats: GetDashboardStats(deps.dashboardRepository),
          getRevenueChart: GetRevenueChart(deps.analyticsRepository),
        )..add(const DashboardStarted()),
        child: AdminDashboardScreen(
          exportRepository: deps.revenueReportRepository,
          fileOpener: deps.reportFileOpener,
        ),
      ),
    ),
    FcRoute(
      path: '/admin/analytics',
      builder: (context, state) => BlocProvider(
        create: (_) => AnalyticsBloc(
          getBranches: GetBranches(branches),
          getRevenueChart: GetRevenueChart(deps.analyticsRepository),
          getInsights: GetCourtInsights(deps.analyticsRepository),
        )..add(const AnalyticsStarted()),
        child: const AnalyticsScreen(),
      ),
    ),
    FcRoute(
      path: '/admin/branches',
      builder: (context, state) => BlocProvider(
        create: (_) =>
            BranchListBloc(GetBranches(branches))
              ..add(const BranchListRequested()),
        child: BranchListScreen(
          onCreateBranch: () => context.push<Branch>('/admin/branches/new'),
          onEditBranch: (branch) =>
              context.push<Branch>('/admin/branches/${branch.id}/edit'),
          onOpenCourts: (branch) =>
              context.push('/admin/branches/${branch.id}/courts'),
          onOpenImages: images == null
              ? null
              : (branch) => context.push('/admin/branches/${branch.id}/images'),
          onOpenPayments: hasPayments
              ? (branch) =>
                    context.push('/admin/branches/${branch.id}/payments')
              : null,
          onOpenRefunds: hasRefunds
              ? (branch) => context.push('/admin/branches/${branch.id}/refunds')
              : null,
          onOpenTransactions: hasTransactions
              ? (branch) =>
                    context.push('/admin/branches/${branch.id}/transactions')
              : null,
        ),
      ),
    ),
    FcRoute(
      path: '/admin/branches/new',
      builder: (context, state) => BlocProvider(
        create: (_) => BranchFormBloc(
          getBranch: GetBranch(branches),
          saveBranch: SaveBranch(branches),
        ),
        child: const BranchFormScreen(),
      ),
    ),
    FcRoute(
      path: '/admin/branches/:branchId/edit',
      builder: (context, state) => _withId(
        state.pathParameters['branchId'],
        (id) => BlocProvider(
          create: (_) => BranchFormBloc(
            getBranch: GetBranch(branches),
            saveBranch: SaveBranch(branches),
            branchId: id,
          )..add(const BranchFormStarted()),
          child: const BranchFormScreen(),
        ),
      ),
    ),
    FcRoute(
      path: '/admin/branches/:branchId/courts',
      builder: (context, state) => _withId(
        state.pathParameters['branchId'],
        (id) => BlocProvider(
          create: (_) => CourtListBloc(
            getBranches: GetBranches(branches),
            getCourts: GetCourts(courts),
            getCourtTypes: GetCourtTypes(deps.courtTypeRepository),
            toggleMaintenance: ToggleCourtMaintenance(courts),
          )..add(CourtListStarted(id)),
          child: CourtListScreen(
            onCreateCourt: (branchId) =>
                context.push<Court>('/admin/courts/new?branchId=$branchId'),
            onEditCourt: (court) =>
                context.push<Court>('/admin/courts/${court.id}/edit'),
            onOpenSlotTemplate: (court) =>
                context.push('/admin/courts/${court.id}/slot-template'),
            onOpenPricing: (court) =>
                context.push('/admin/courts/${court.id}/pricing'),
            onBulkApply: (branch, branchCourts) => showBulkApplyTemplateDialog(
              context,
              createBloc: () => BulkApplyTemplateBloc(
                courts: branchCourts,
                start: branch.openTime,
                end: branch.closeTime,
                branchOpen: branch.openTime,
                branchClose: branch.closeTime,
                previewBulk: PreviewBulkSlotTemplate(
                  deps.slotTemplateRepository,
                ),
                applyBulk: ApplyBulkSlotTemplate(deps.slotTemplateRepository),
              ),
            ),
            onOpenCalendar: deps.courtCalendarRepository == null
                ? null
                : (court) => context.push('/admin/courts/${court.id}/calendar'),
            onOpenOutOfService: deps.courtLockRepository == null
                ? null
                : (branchId) =>
                      context.push('/admin/branches/$branchId/out-of-service'),
          ),
        ),
      ),
    ),
    FcRoute(
      path: '/admin/courts/new',
      builder: (context, state) => _withId(
        state.uri.queryParameters['branchId'],
        (branchId) => BlocProvider(
          create: (_) => CourtFormBloc(
            getCourt: GetCourt(courts),
            saveCourt: SaveCourt(courts),
            getCourtTypes: GetCourtTypes(deps.courtTypeRepository),
            branchId: branchId,
          )..add(const CourtFormStarted()),
          child: const CourtFormScreen(),
        ),
      ),
    ),
    FcRoute(
      path: '/admin/courts/:courtId/edit',
      builder: (context, state) => _withId(
        state.pathParameters['courtId'],
        (courtId) => BlocProvider(
          create: (_) => CourtFormBloc(
            getCourt: GetCourt(courts),
            saveCourt: SaveCourt(courts),
            getCourtTypes: GetCourtTypes(deps.courtTypeRepository),
            courtId: courtId,
          )..add(const CourtFormStarted()),
          child: const CourtFormScreen(),
        ),
      ),
    ),
    FcRoute(
      path: '/admin/courts/:courtId/pricing',
      builder: (context, state) => _withId(
        state.pathParameters['courtId'],
        (courtId) => BlocProvider(
          create: (_) => PricingRuleBloc(
            courtId: courtId,
            getCourt: GetCourt(courts),
            getRules: GetPricingRules(deps.pricingRuleRepository),
            saveRule: SavePricingRule(deps.pricingRuleRepository),
            deleteRule: DeletePricingRule(deps.pricingRuleRepository),
            copyToWeekend: CopyWeekdayToWeekend(deps.pricingRuleRepository),
          )..add(const PricingRuleStarted()),
          child: const PricingRuleConfigScreen(),
        ),
      ),
    ),
    FcRoute(
      path: '/admin/courts/:courtId/slot-template',
      builder: (context, state) => _withId(
        state.pathParameters['courtId'],
        (courtId) => BlocProvider(
          create: (_) => SlotTemplateBloc(
            courtId: courtId,
            getCourt: GetCourt(courts),
            getBranch: GetBranch(branches),
            applyTemplate: ApplySlotTemplate(deps.slotTemplateRepository),
          )..add(const SlotTemplateStarted()),
          child: const TimeSlotTemplateScreen(),
        ),
      ),
    ),
    if (deps.courtLockRepository != null &&
        deps.courtCalendarRepository != null)
      FcRoute(
        path: '/admin/courts/:courtId/calendar',
        builder: (context, state) => _withId(
          state.pathParameters['courtId'],
          (courtId) => BlocProvider(
            create: (_) => CourtCalendarBloc(
              courtId: courtId,
              getCourt: GetCourt(courts),
              getDays: GetCalendarDays(deps.courtCalendarRepository!),
              getLocks: GetCourtLocks(deps.courtLockRepository!),
              lockCourt: LockCourt(deps.courtLockRepository!),
              unlockCourt: UnlockCourt(deps.courtLockRepository!),
            )..add(const CalendarStarted()),
            child: CourtCalendarScreen(
              onOpenOutOfService: (branchId) =>
                  context.push('/admin/branches/$branchId/out-of-service'),
            ),
          ),
        ),
      ),
    if (deps.courtLockRepository != null)
      FcRoute(
        path: '/admin/branches/:branchId/out-of-service',
        builder: (context, state) => _withId(
          state.pathParameters['branchId'],
          (branchId) => BlocProvider(
            create: (_) => OutOfServiceBloc(
              branchId: branchId,
              getBranch: GetBranch(branches),
              getCourts: GetCourts(courts),
              getLocks: GetCourtLocks(deps.courtLockRepository!),
              lockBranch: LockBranch(deps.courtLockRepository!),
              unlockCourt: UnlockCourt(deps.courtLockRepository!),
              unlockGroup: UnlockGroup(deps.courtLockRepository!),
            )..add(const OutOfServiceStarted()),
            child: const OutOfServiceManagementScreen(),
          ),
        ),
      ),
  ];
}

/// ID trong URL phải là số nguyên dương; sai thì báo lỗi thay vì gọi API.
Widget _withId(String? raw, Widget Function(int id) builder) {
  final id = int.tryParse(raw ?? '');
  if (id == null || id <= 0) {
    return Scaffold(
      appBar: AppBar(),
      body: const Center(child: Text('Đường dẫn không hợp lệ.')),
    );
  }
  return builder(id);
}
