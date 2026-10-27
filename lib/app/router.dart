import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/health/domain/usecases/get_health_status.dart';
import '../features/health/presentation/bloc/health_bloc.dart';
import '../features/health/presentation/pages/health_page.dart';
import 'app_dependencies.dart';
import '../features/payment/presentation/pages/payment_waiting_screen.dart';
import '../features/payment/domain/entities/payment_checkout.dart';
import '../features/payment/presentation/pages/payment_checkout_screen.dart';

GoRouter createRouter(AppDependencies dependencies) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/payments/receipt',
        builder: (context, state) {
          final args = state.extra;
          final repository = dependencies.receiptRepository;
          final picker = dependencies.receiptPicker;
          if (args is! CheckoutArguments ||
              repository == null ||
              picker == null) {
            return const Scaffold(
              body: Center(child: Text('Vui lòng chọn đơn đặt sân.')),
            );
          }
          return PaymentWaitingScreen(
            repository: repository,
            picker: picker,
            arguments: args,
            onConfirmed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Thanh toán đã xác nhận')),
            ),
          );
        },
      ),
      GoRoute(
        path: '/payments/checkout',
        builder: (context, state) {
          final arguments = state.extra;
          final repository = dependencies.paymentRepository;
          final saver = dependencies.qrSaver;
          if (arguments is! CheckoutArguments ||
              repository == null ||
              saver == null) {
            return const Scaffold(
              body: Center(
                child: Text('Vui lòng chọn đơn đặt sân trước khi thanh toán.'),
              ),
            );
          }
          return PaymentCheckoutScreen(
            repository: repository,
            saver: saver,
            arguments: arguments,
            onUploadReceipt: () =>
                context.push('/payments/receipt', extra: arguments),
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
