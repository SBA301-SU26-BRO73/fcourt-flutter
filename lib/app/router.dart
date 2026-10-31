import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/health/domain/usecases/get_health_status.dart';
import '../features/health/presentation/bloc/health_bloc.dart';
import '../features/health/presentation/pages/health_page.dart';
import 'admin_facility_routes.dart';
import 'app_dependencies.dart';

GoRouter createRouter(AppDependencies dependencies) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => BlocProvider(
          create: (_) => HealthBloc(GetHealthStatus(dependencies.healthRepository))
            ..add(const HealthCheckRequested()),
          child: HealthPage(config: dependencies.config),
        ),
      ),
      ...adminFacilityRoutes(dependencies.adminFacility),
    ],
  );
}
