import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/health/domain/usecases/get_health_status.dart';
import '../features/health/presentation/bloc/health_bloc.dart';
import '../features/health/presentation/pages/health_page.dart';
import 'app_dependencies.dart';
import '../features/booking/presentation/pages/booking_summary_screen.dart';

GoRouter createRouter(AppDependencies dependencies) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/booking/summary',
        builder: (context, state) {
          final arguments = state.extra;
          final repository = dependencies.bookingRepository;
          if (arguments is! BookingSummaryArguments || repository == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Đặt sân')),
              body: const Center(
                child: Text('Vui lòng chọn sân và khung giờ trước khi đặt.'),
              ),
            );
          }
          return BookingSummaryScreen(
            repository: repository,
            arguments: arguments,
          );
        },
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
