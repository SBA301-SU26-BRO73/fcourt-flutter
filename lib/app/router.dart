import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/health/domain/usecases/get_health_status.dart';
import '../features/health/presentation/bloc/health_bloc.dart';
import '../features/health/presentation/pages/health_page.dart';
import 'app_dependencies.dart';
import '../src/features/customer_discovery/domain/discovery_repository.dart';
import '../src/features/customer_discovery/presentation/discovery_cubit.dart';
import '../src/features/customer_discovery/presentation/screens/customer_home_screen.dart';
import '../src/features/customer_discovery/presentation/screens/branch_list_screen.dart';
import '../src/features/customer_discovery/presentation/screens/branch_detail_screen.dart';

GoRouter createRouter(AppDependencies dependencies) {
  return GoRouter(
    routes: [
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
    ],
  );
}
