import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/health/domain/usecases/get_health_status.dart';
import '../features/health/presentation/bloc/health_bloc.dart';
import '../features/health/presentation/pages/health_page.dart';
import 'app_dependencies.dart';
import '../features/staff/presentation/staff_page.dart';

GoRouter createRouter(AppDependencies dependencies) {
  return GoRouter(
    routes: [
      if (dependencies.staffRepository != null)
        GoRoute(
          path: '/admin/staff',
          builder: (_, _) =>
              StaffPage(repository: dependencies.staffRepository!),
        ),
      GoRoute(
        path: '/',
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
