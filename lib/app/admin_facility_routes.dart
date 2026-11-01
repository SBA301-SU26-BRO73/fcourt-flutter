import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/admin_dashboard/domain/usecases/get_dashboard_stats.dart';
import '../features/admin_dashboard/presentation/bloc/dashboard_bloc.dart';
import '../features/admin_dashboard/presentation/pages/admin_dashboard_screen.dart';
import '../features/admin_facility/domain/entities/branch.dart';
import '../features/admin_facility/domain/entities/court.dart';
import '../features/admin_facility/domain/usecases/apply_slot_template.dart';
import '../features/admin_facility/domain/usecases/branch_usecases.dart';
import '../features/admin_facility/domain/usecases/court_usecases.dart';
import '../features/admin_facility/presentation/bloc/branch_form_bloc.dart';
import '../features/admin_facility/presentation/bloc/branch_list_bloc.dart';
import '../features/admin_facility/presentation/bloc/court_form_bloc.dart';
import '../features/admin_facility/presentation/bloc/court_list_bloc.dart';
import '../features/admin_facility/presentation/bloc/slot_template_bloc.dart';
import '../features/admin_facility/presentation/pages/branch_form_screen.dart';
import '../features/admin_facility/presentation/pages/branch_list_screen.dart';
import '../features/admin_facility/presentation/pages/court_form_screen.dart';
import '../features/admin_facility/presentation/pages/court_list_screen.dart';
import '../features/admin_facility/presentation/pages/time_slot_template_screen.dart';
import 'admin_facility_dependencies.dart';

/// Route của chủ sân (SCRUM-13/15/17/19). Trả về danh sách rỗng khi app chưa
/// cấu hình repository (ví dụ trong test của feature khác).
List<RouteBase> adminFacilityRoutes(AdminFacilityDependencies? deps) {
  if (deps == null) return const [];
  final branches = deps.branchRepository;
  final courts = deps.courtRepository;
  return [
    GoRoute(
      path: '/admin/dashboard',
      builder: (context, state) => BlocProvider(
        create: (_) => DashboardBloc(
          getBranches: GetBranches(branches),
          getStats: GetDashboardStats(deps.dashboardRepository),
        )..add(const DashboardStarted()),
        child: AdminDashboardScreen(
          onOpenBranches: () => context.push('/admin/branches'),
        ),
      ),
    ),
    GoRoute(
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
          onOpenDashboard: () => context.push('/admin/dashboard'),
        ),
      ),
    ),
    GoRoute(
      path: '/admin/branches/new',
      builder: (context, state) => BlocProvider(
        create: (_) => BranchFormBloc(
          getBranch: GetBranch(branches),
          saveBranch: SaveBranch(branches),
        ),
        child: const BranchFormScreen(),
      ),
    ),
    GoRoute(
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
    GoRoute(
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
          ),
        ),
      ),
    ),
    GoRoute(
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
    GoRoute(
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
    GoRoute(
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
