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

GoRouter createRouter(AppDependencies dependencies) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
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
