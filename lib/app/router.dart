import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/health/domain/usecases/get_health_status.dart';
import '../features/health/presentation/bloc/health_bloc.dart';
import '../features/health/presentation/pages/health_page.dart';
import '../features/super_admin/domain/usecases/owner_approval_usecases.dart';
import '../features/super_admin/presentation/bloc/owner_detail_cubit.dart';
import '../features/super_admin/presentation/bloc/pending_owners_cubit.dart';
import '../features/super_admin/presentation/pages/owner_approval_detail_screen.dart';
import '../features/super_admin/presentation/pages/pending_owners_screen.dart';
import 'app_dependencies.dart';
import '../src/features/customer_discovery/domain/discovery_repository.dart';
import '../src/features/customer_discovery/presentation/discovery_cubit.dart';
import '../src/features/customer_discovery/presentation/screens/customer_home_screen.dart';
import '../src/features/customer_discovery/presentation/screens/branch_list_screen.dart';
import '../src/features/customer_discovery/presentation/screens/branch_detail_screen.dart';
import '../src/features/customer_slots/presentation/slot_picker_screen.dart';
import '../src/features/customer_slots/domain/court_slot.dart';

GoRouter createRouter(AppDependencies dependencies) {
  return GoRouter(
    routes: [
      GoRoute(
        name: 'courtSlots',
        path: '/courts/:courtId/slots',
        builder: (context, state) {
          final courtId = int.tryParse(state.pathParameters['courtId'] ?? '');
          final repository = dependencies.slotRepository;
          if (courtId == null || courtId <= 0 || repository == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Lịch sân trống')),
              body: const Center(
                child: Text('Vui lòng chọn sân hợp lệ để xem lịch.'),
              ),
            );
          }
          final dateText = state.uri.queryParameters['date'];
          final parsed = dateText == null ? null : DateTime.tryParse(dateText);
          return SlotPickerScreen(
            repository: repository,
            courtId: courtId,
            courtName: state.uri.queryParameters['courtName'],
            branchName: state.uri.queryParameters['branchName'],
            date: parsed != null && slotDateKey(parsed) == dateText
                ? parsed
                : null,
          );
        },
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const CustomerHomeScreen(),
      ),
      GoRoute(
        path: '/branches',
        builder: (context, state) {
          final sportName = state.uri.queryParameters['sport'];
          final sports = DiscoverySport.values.where(
            (s) => s.name == sportName,
          );
          return BlocProvider(
            create: (_) => DiscoveryCubit(
              dependencies.discoveryRepository,
              query: state.uri.queryParameters['query'] ?? '',
              sport: sports.firstOrNull,
            )..refresh(),
            child: const BranchListScreen(),
          );
        },
      ),
      GoRoute(
        path: '/branches/:id',
        builder: (context, state) => BranchDetailScreen(
          branchId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
          branch: state.extra is Branch ? state.extra as Branch : null,
        ),
      ),
      GoRoute(
        path: '/health',
        builder: (context, state) => BlocProvider(
          create: (_) =>
              HealthBloc(GetHealthStatus(dependencies.healthRepository))
                ..add(const HealthCheckRequested()),
          child: HealthPage(config: dependencies.config),
        ),
      ),
      GoRoute(
        path: '/super-admin/owners/pending',
        builder: (context, state) {
          final repository = dependencies.courtOwnerApprovalRepository;
          if (repository == null) return const _UnavailableScreen();
          return BlocProvider(
            create: (_) =>
                PendingOwnersCubit(GetPendingOwners(repository))..load(),
            child: PendingOwnersScreen(
              onOpenOwner: (owner) => context.push<OwnerDecision>(
                '/super-admin/owners/${owner.id}',
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/super-admin/owners/:ownerId',
        builder: (context, state) {
          final repository = dependencies.courtOwnerApprovalRepository;
          final id = int.tryParse(state.pathParameters['ownerId'] ?? '');
          if (repository == null || id == null || id <= 0) {
            return const _UnavailableScreen();
          }
          return BlocProvider(
            create: (_) => OwnerDetailCubit(
              ownerId: id,
              getOwnerDetail: GetOwnerDetail(repository),
              approveOwner: ApproveOwner(repository),
              rejectOwner: RejectOwner(repository),
            )..load(),
            child: const OwnerApprovalDetailScreen(),
          );
        },
      ),
    ],
  );
}

class _UnavailableScreen extends StatelessWidget {
  const _UnavailableScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Không tìm thấy hồ sơ chủ sân.')),
  );
}
