import '../features/transactions/presentation/admin_transaction_history_screen.dart';
import '../features/transactions/presentation/customer_transaction_history_screen.dart';
import '../features/booking_history/presentation/booking_history_screen.dart';
import '../features/booking_history/presentation/booking_detail_screen.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/health/domain/usecases/get_health_status.dart';
import '../features/health/presentation/bloc/health_bloc.dart';
import '../features/health/presentation/pages/health_page.dart';
import 'app_dependencies.dart';
import '../features/payment/presentation/pages/booking_success_screen.dart';
import '../features/payment/presentation/pages/admin_payment_approval_screen.dart';
import '../features/payment/presentation/pages/payment_waiting_screen.dart';
import '../features/payment/domain/entities/payment_checkout.dart';
import '../features/payment/presentation/pages/payment_checkout_screen.dart';

GoRouter createRouter(AppDependencies dependencies) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/admin/branches/:branchId/transactions',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['branchId'] ?? '');
          final repository = dependencies.adminTransactions;
          if (id == null || id <= 0 || repository == null) {
            return const Scaffold(
              body: Center(child: Text('Vui lòng chọn chi nhánh hợp lệ')),
            );
          }
          return AdminTransactionHistoryScreen(
            repository: repository,
            branchId: id,
          );
        },
      ),
      GoRoute(
        path: '/payments/history',
        builder: (context, state) {
          final repository = dependencies.customerTransactions;
          if (repository == null) {
            return const Scaffold(
              body: Center(child: Text('Lịch sử thanh toán chưa khả dụng')),
            );
          }
          return CustomerTransactionHistoryScreen(repository: repository);
        },
      ),
      GoRoute(
        path: '/bookings',
        builder: (context, state) {
          final repository = dependencies.bookingRepository;
          if (repository == null) {
            return const Scaffold(
              body: Center(child: Text('Lịch sử đặt sân chưa khả dụng')),
            );
          }
          return BookingHistoryScreen(
            repository: repository,
            onDetail: (id) => context.push('/bookings/$id'),
            onTransactions: dependencies.customerTransactions == null
                ? null
                : () => context.push('/payments/history'),
          );
        },
      ),
      GoRoute(
        path: '/bookings/:id',
        builder: (context, state) {
          final repository = dependencies.bookingRepository;
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (repository == null || id == null || id <= 0) {
            return const Scaffold(
              body: Center(child: Text('Đơn đặt sân không hợp lệ')),
            );
          }
          return BookingDetailScreen(
            repository: repository,
            id: id,
            cancellation: dependencies.cancellationRepository,
            onTicket:
                dependencies.ticketRepository == null ||
                    dependencies.ticketSaver == null
                ? null
                : (id) => showDialog<void>(
                    context: context,
                    builder: (_) => Dialog.fullscreen(
                      child: BookingSuccessScreen(
                        repository: dependencies.ticketRepository!,
                        saver: dependencies.ticketSaver!,
                        arguments: CheckoutArguments(bookingId: id),
                      ),
                    ),
                  ),
          );
        },
      ),
      GoRoute(
        path: '/payments/ticket',
        builder: (context, state) {
          final args = state.extra;
          final repository = dependencies.ticketRepository;
          final saver = dependencies.ticketSaver;
          if (args is! CheckoutArguments ||
              repository == null ||
              saver == null) {
            return const Scaffold(
              body: Center(child: Text('Vui lòng chọn vé đặt sân.')),
            );
          }
          return BookingSuccessScreen(
            repository: repository,
            saver: saver,
            arguments: args,
            onHistory:
                dependencies.onBookingHistory ??
                (dependencies.bookingRepository == null
                    ? null
                    : () => context.go('/bookings')),
          );
        },
      ),
      GoRoute(
        path: '/admin/branches/:branchId/payments',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['branchId'] ?? '');
          final repository = dependencies.adminPaymentRepository;
          if (id == null || id <= 0 || repository == null) {
            return const Scaffold(
              body: Center(child: Text('Vui lòng chọn chi nhánh hợp lệ.')),
            );
          }
          return AdminPaymentApprovalScreen(
            repository: repository,
            branchId: id,
            onLedger: dependencies.adminTransactions == null
                ? null
                : () => context.push('/admin/branches/$id/transactions'),
          );
        },
      ),
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
            onConfirmed: () => context.go('/payments/ticket', extra: args),
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
