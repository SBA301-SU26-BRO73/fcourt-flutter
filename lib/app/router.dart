import '../features/customer_hub/presentation/customer_hub_pages.dart';
import '../features/auth/domain/entities/user_role.dart';
import 'widgets/app_shell.dart';
import 'booking_selection_adapter.dart';
import '../features/booking/domain/entities/booking_hold.dart';
import '../features/booking/domain/repositories/booking_creation_repository.dart';
import '../features/booking/presentation/pages/booking_create_screen.dart';
import '../features/booking/presentation/guest_booking_lookup_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../src/features/customer_slots/data/stomp_slot_invalidations.dart';

import 'dart:async';

import '../features/reviews/presentation/rating_bottom_sheet.dart';

import '../features/subscription/presentation/subscription_cubit.dart';
import '../features/subscription/presentation/subscription_screen.dart';
import '../features/admin_bookings/domain/admin_booking_status.dart';
import '../features/admin_bookings/presentation/admin_booking_cubit.dart';
import '../features/admin_dashboard/presentation/widgets/owner_todo_panel.dart';
import '../features/admin_bookings/presentation/admin_booking_management_screen.dart';
import '../features/vouchers/presentation/voucher_cubit.dart';
import '../features/vouchers/presentation/voucher_management_screen.dart';
import 'post_payment_navigation.dart';
import '../features/refunds/presentation/admin_refund_approval_screen.dart';
import '../features/refunds/presentation/customer_refund_screen.dart';
import '../features/transactions/presentation/admin_transaction_history_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'fc_route.dart';

import '../features/auth/domain/usecases/change_password.dart';
import '../features/auth/domain/usecases/login.dart';
import '../features/auth/domain/usecases/register_court_owner.dart';
import '../features/auth/domain/usecases/register_customer.dart';
import '../features/auth/domain/usecases/request_password_reset.dart';
import '../features/auth/domain/usecases/reset_password.dart';
import '../features/auth/domain/usecases/update_profile.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/bloc/change_password_bloc.dart';
import '../features/auth/presentation/bloc/forgot_password_bloc.dart';
import '../features/auth/presentation/bloc/login_bloc.dart';
import '../features/auth/presentation/bloc/profile_bloc.dart';
import '../features/auth/presentation/bloc/register_bloc.dart';
import '../features/auth/presentation/bloc/reset_password_bloc.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/auth/presentation/pages/home_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/profile_page.dart';
import '../features/auth/presentation/pages/register_customer_page.dart';
import '../features/auth/presentation/pages/register_owner_page.dart';
import '../features/auth/presentation/pages/reset_password_page.dart';
import '../features/auth/presentation/pages/splash_page.dart';
import '../features/catalog/domain/entities/court_type.dart';
import '../features/catalog/domain/entities/subscription_plan.dart';
import '../features/catalog/domain/usecases/delete_court_type.dart';
import '../features/catalog/domain/usecases/delete_subscription_plan.dart';
import '../features/catalog/domain/usecases/list_court_types.dart';
import '../features/catalog/domain/usecases/list_subscription_plans.dart';
import '../features/catalog/domain/usecases/save_court_type.dart';
import '../features/catalog/domain/usecases/save_subscription_plan.dart';
import '../features/catalog/presentation/bloc/catalog_list_bloc.dart';
import '../features/catalog/presentation/pages/catalog_page.dart';
import '../features/health/domain/usecases/get_health_status.dart';
import '../features/health/presentation/bloc/health_bloc.dart';
import '../features/health/presentation/pages/health_page.dart';
import '../features/super_admin/domain/repositories/platform_overview_repository.dart';
import '../features/super_admin/domain/usecases/owner_approval_usecases.dart';
import '../features/super_admin/presentation/bloc/platform_overview_cubit.dart';
import '../features/super_admin/presentation/pages/super_admin_overview_screen.dart';
import '../features/super_admin/presentation/bloc/owner_detail_cubit.dart';
import '../features/super_admin/presentation/bloc/pending_owners_cubit.dart';
import '../features/super_admin/presentation/pages/owner_approval_detail_screen.dart';
import '../features/super_admin/presentation/pages/pending_owners_screen.dart';
import 'admin_facility_routes.dart';
import 'app_dependencies.dart';
import 'auth_redirect.dart';
import '../features/staff/presentation/staff_page.dart';
import '../features/pos/presentation/pos_page.dart';
import '../features/operations/presentation/schedule_page.dart';
import '../features/offline/data/offline_operations.dart';
import '../features/offline/presentation/offline_check_in_page.dart';
import '../features/offline/presentation/offline_panel.dart';
import '../src/features/customer_discovery/domain/discovery_repository.dart';
import '../src/features/customer_discovery/presentation/discovery_cubit.dart';
import '../src/features/customer_discovery/presentation/screens/customer_home_screen.dart';
import '../src/features/customer_discovery/presentation/screens/branch_list_screen.dart';
import '../src/features/customer_discovery/presentation/screens/branch_detail_screen.dart';
import '../src/features/customer_slots/presentation/slot_picker_screen.dart';
import '../src/features/customer_slots/domain/court_slot.dart';
import '../features/booking/presentation/pages/booking_summary_screen.dart';
import '../features/payment/domain/entities/payment_checkout.dart';
import '../features/payment/presentation/pages/payment_checkout_screen.dart';
import '../features/transactions/presentation/customer_transaction_history_screen.dart';
import '../features/booking_history/presentation/booking_history_screen.dart';
import '../features/booking_history/presentation/booking_detail_screen.dart';
import '../features/payment/presentation/pages/booking_success_screen.dart';
import '../features/payment/presentation/pages/admin_payment_approval_screen.dart';
import '../features/payment/presentation/pages/payment_waiting_screen.dart';

/// Báo cho router đánh giá lại [GoRouter.redirect] mỗi khi trạng thái đăng nhập đổi.
class AuthRefreshNotifier extends ChangeNotifier {
  AuthRefreshNotifier(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

GoRouter createRouter(
  AppDependencies dependencies,
  AuthBloc authBloc, {
  Listenable? refreshListenable,
}) {
  final repository = dependencies.authRepository;
  final catalog = dependencies.catalogRepository;
  var ratingOpen = false;
  Future<bool> rate(BuildContext context, int bookingId) async {
    final reviews = dependencies.reviews;
    if (ratingOpen || reviews == null) return false;
    ratingOpen = true;
    try {
      final result = await showRatingBottomSheet(
        context,
        repository: reviews,
        bookingId: bookingId,
        picker: dependencies.reviewPhotoPicker,
        uploader: dependencies.reviewPhotoUploader,
      );
      if (context.mounted && result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cảm ơn bạn đã đánh giá sân!')),
        );
      }
      return result != null;
    } finally {
      ratingOpen = false;
    }
  }

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final auth = authBloc.state;
      final redirect = authRedirect(
        auth.status,
        state.matchedLocation,
        role: auth.role,
        returnTo: state.uri.queryParameters['from'],
      );
      if (auth.status == AuthStatus.unauthenticated &&
          redirect == AppRoutes.login &&
          state.matchedLocation != AppRoutes.login) {
        return Uri(
          path: AppRoutes.login,
          queryParameters: {'from': state.uri.toString()},
        ).toString();
      }
      return redirect;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(
          location: state.uri.path,
          notificationsRepository: dependencies.notificationsRepository,
          child: child,
        ),
        routes: [
          FcRoute(path: '/activity', builder: (_, _) => const ActivityPage()),
          FcRoute(
            path: '/notifications',
            builder: (_, _) => NotificationsPage(
              repository: dependencies.notificationsRepository,
            ),
          ),
          FcRoute(
            path: '/lookup',
            builder: (_, _) => GuestBookingLookupPage(
              repository: dependencies.guestBookingLookupRepository,
            ),
          ),
          FcRoute(
            path: AppRoutes.settings,
            builder: (_, _) => const SettingsPage(),
          ),
          FcRoute(
            path: '/admin/subscription',
            builder: (context, state) {
              final repository = dependencies.subscriptions;
              if (repository == null) {
                return const Scaffold(
                  body: Center(child: Text('Gói dịch vụ chưa khả dụng')),
                );
              }
              return BlocProvider(
                create: (_) => SubscriptionCubit(
                  repository,
                  dependencies.subscriptionCheckoutLauncher,
                )..refresh(),
                child: const SubscriptionScreen(),
              );
            },
          ),
          if (dependencies.offline != null)
            FcRoute(
              path: AppRoutes.offlineCheckIn,
              builder: (_, _) => OfflineCheckInPage(
                repository: OfflineOperations.cached(
                  dependencies.offline!.coordinator,
                ),
                syncPanel: OfflinePanel(runtime: dependencies.offline!),
                onReconnect: () => authBloc.add(const AuthStarted()),
                onLogin: () => authBloc.add(const AuthSessionExpired()),
              ),
            ),
          if (dependencies.pos != null)
            FcRoute(
              path: '/staff/pos',
              builder: (_, _) => PosPage(
                repository: dependencies.pos!,
                journal: dependencies.posSaleStore?.call(),
              ),
            ),
          if (dependencies.operations != null)
            FcRoute(
              path: '/staff/schedule',
              builder: (_, _) => SchedulePage(
                repository: dependencies.operations!,
                counter: dependencies.counter,
                offline: dependencies.offline,
              ),
            ),
          if (dependencies.staffRepository != null)
            FcRoute(
              path: AppRoutes.staff,
              builder: (_, _) =>
                  StaffPage(repository: dependencies.staffRepository!),
            ),
          FcRoute(
            path: AppRoutes.splash,
            builder: (context, state) => const SplashPage(),
          ),
          FcRoute(
            path: AppRoutes.login,
            builder: (context, state) => BlocProvider(
              create: (_) => LoginBloc(Login(repository)),
              child: const LoginPage(),
            ),
          ),
          FcRoute(
            path: AppRoutes.registerCustomer,
            builder: (context, state) => BlocProvider(
              create: (_) => RegisterBloc(
                RegisterCustomer(repository),
                RegisterCourtOwner(repository),
              ),
              child: const RegisterCustomerPage(),
            ),
          ),
          FcRoute(
            path: AppRoutes.registerOwner,
            builder: (context, state) => BlocProvider(
              create: (_) => RegisterBloc(
                RegisterCustomer(repository),
                RegisterCourtOwner(repository),
              ),
              child: RegisterOwnerPage(picker: dependencies.documentPicker),
            ),
          ),
          FcRoute(
            path: AppRoutes.forgotPassword,
            builder: (context, state) => BlocProvider(
              create: (_) =>
                  ForgotPasswordBloc(RequestPasswordReset(repository)),
              child: const ForgotPasswordPage(),
            ),
          ),
          FcRoute(
            path: AppRoutes.resetPassword,
            builder: (context, state) => BlocProvider(
              create: (_) => ResetPasswordBloc(ResetPassword(repository)),
              child: ResetPasswordPage(
                initialToken: state.uri.queryParameters['token'],
              ),
            ),
          ),
          FcRoute(
            path: '/booking/confirm',
            builder: (context, state) {
              final checkout = state.extra;
              final creator = dependencies.bookingRepository;
              if (checkout is! BookingCheckout ||
                  creator is! BookingCreationRepository) {
                return const Scaffold(
                  body: Center(
                    child: Text(
                      'Vui lòng chọn sân và khung giờ trước khi đặt.',
                    ),
                  ),
                );
              }
              return BookingCreateScreen(
                repository: creator as BookingCreationRepository,
                checkout: checkout,
                onCreated: (arguments) =>
                    context.replace('/payments/checkout', extra: arguments),
                onHistory: () => context.go('/bookings'),
              );
            },
          ),
          FcRoute(
            path: '/booking/summary',
            builder: (context, state) {
              final arguments = state.extra;
              final bookingRepository = dependencies.bookingRepository;
              if (arguments is! BookingSummaryArguments ||
                  bookingRepository == null) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Đặt sân')),
                  body: const Center(
                    child: Text(
                      'Vui lòng chọn sân và khung giờ trước khi đặt.',
                    ),
                  ),
                );
              }
              return BookingSummaryScreen(
                repository: bookingRepository,
                arguments: arguments,
              );
            },
          ),
          FcRoute(
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
                onRefunds: dependencies.adminRefunds == null
                    ? null
                    : () => context.push('/admin/branches/$id/refunds'),
                onLedger: dependencies.adminTransactions == null
                    ? null
                    : () => context.push('/admin/branches/$id/transactions'),
              );
            },
          ),
          FcRoute(
            path: '/admin/branches/:branchId/refunds',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['branchId'] ?? '');
              final repository = dependencies.adminRefunds;
              final picker = dependencies.receiptPicker;
              if (id == null ||
                  id <= 0 ||
                  repository == null ||
                  picker == null) {
                return const Scaffold(
                  body: Center(child: Text('Vui lòng chọn chi nhánh hợp lệ')),
                );
              }
              return AdminRefundApprovalScreen(
                repository: repository,
                picker: picker,
                branchId: id,
              );
            },
          ),
          FcRoute(
            path: '/bookings/:id/refund',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              final repository = dependencies.refundRepository;
              if (id == null || id <= 0 || repository == null) {
                return const Scaffold(
                  body: Center(child: Text('Vui lòng chọn đơn hợp lệ')),
                );
              }
              return CustomerRefundScreen(
                repository: repository,
                bookingId: id,
                userId: authBloc.state.user?.id,
              );
            },
          ),
          FcRoute(
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
                exporter: dependencies.ledgerExporter,
                revenueReports:
                    dependencies.adminFacility?.revenueReportRepository,
                fileOpener: dependencies.adminFacility?.reportFileOpener,
              );
            },
          ),
          FcRoute(
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
          FcRoute(
            path: '/bookings',
            builder: (context, state) {
              final repository = dependencies.bookingHistoryRepository;
              if (repository == null) {
                return const Scaffold(
                  body: Center(child: Text('Lịch sử đặt sân chưa khả dụng')),
                );
              }
              return BookingHistoryScreen(
                onReview: dependencies.reviews == null
                    ? null
                    : (id) => rate(context, id),
                repository: repository,
                cacheUserId: authBloc.state.user?.id,
                onDetail: (id) => context.push('/bookings/$id'),
                onTransactions: dependencies.customerTransactions == null
                    ? null
                    : () => context.push('/payments/history'),
              );
            },
          ),
          FcRoute(
            path: '/bookings/:id',
            builder: (context, state) {
              final repository = dependencies.bookingHistoryRepository;
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              if (repository == null || id == null || id <= 0) {
                return const Scaffold(
                  body: Center(child: Text('Đơn đặt sân không hợp lệ')),
                );
              }
              return BookingDetailScreen(
                onReview: dependencies.reviews == null
                    ? null
                    : (id) => rate(context, id),
                repository: repository,
                id: id,
                cancellation: dependencies.cancellationRepository,
                onRefund: dependencies.refundRepository == null
                    ? null
                    : (id) => context.push('/bookings/$id/refund'),
                onPay:
                    dependencies.paymentRepository == null ||
                        dependencies.qrSaver == null
                    ? null
                    : (id) => context.push(
                        '/payments/checkout',
                        extra: CheckoutArguments(bookingId: id),
                      ),
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
          FcRoute(
            path: '/payments/checkout',
            builder: (context, state) {
              final arguments = state.extra;
              final paymentRepository = dependencies.paymentRepository;
              final saver = dependencies.qrSaver;
              if (arguments is! CheckoutArguments ||
                  paymentRepository == null ||
                  saver == null) {
                return const Scaffold(
                  body: Center(
                    child: Text(
                      'Vui lòng chọn đơn đặt sân trước khi thanh toán.',
                    ),
                  ),
                );
              }
              return PaymentCheckoutScreen(
                repository: paymentRepository,
                saver: saver,
                arguments: arguments,
                promos: dependencies.promos,
                onFreeConfirmed: () =>
                    showTicketOverBookings(context, arguments),
                onUploadReceipt: () =>
                    context.push('/payments/receipt', extra: arguments),
              );
            },
          ),
          FcRoute(
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
                    (dependencies.bookingHistoryRepository == null
                        ? null
                        : () => context.go('/bookings')),
              );
            },
          ),
          FcRoute(
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
                onConfirmed: () => showTicketOverBookings(context, args),
                onSupport: () => showBookingOverList(context, args.bookingId),
                onHome: () => context.go(AppRoutes.home),
                onViewBooking: () =>
                    showBookingOverList(context, args.bookingId),
              );
            },
          ),
          FcRoute(
            path: '/admin/bookings',
            builder: (context, state) {
              final repository = dependencies.adminBookings;
              final facility = dependencies.adminFacility;
              if (repository == null || facility == null) {
                return const Scaffold(
                  body: Center(
                    child: Text('Quản lý đơn đặt sân chưa khả dụng'),
                  ),
                );
              }
              return BlocProvider(
                create: (_) => AdminBookingCubit(
                  repository,
                  facility.branchRepository,
                  facility.courtRepository,
                  defaultStatus: AdminBookingStatus.awaitingConfirmation,
                )..initialize(),
                child: AdminBookingManagementScreen(
                  onReviewPayment: dependencies.adminPaymentRepository == null
                      ? null
                      : (booking) => context.push(
                          '/admin/branches/${booking.branchId}/payments',
                        ),
                ),
              );
            },
          ),
          FcRoute(
            path: '/admin/vouchers',
            builder: (context, state) {
              final repository = dependencies.vouchers;
              final facility = dependencies.adminFacility;
              if (repository == null || facility == null) {
                return const Scaffold(
                  body: Center(child: Text('Quản lý voucher chưa khả dụng')),
                );
              }
              return BlocProvider(
                create: (_) =>
                    VoucherCubit(repository, facility.branchRepository)
                      ..initialize(),
                child: VoucherManagementScreen(
                  usages: dependencies.voucherUsages,
                ),
              );
            },
          ),
          FcRoute(
            path: AppRoutes.home,
            builder: (context, state) =>
                authBloc.state.role == UserRole.customer
                ? CustomerHomeScreen(
                    repository: dependencies.discoveryRepository,
                  )
                : HomePage(
                    discoveryRepository: dependencies.discoveryRepository,
                    adminTodo:
                        authBloc.state.role == UserRole.admin &&
                            dependencies.adminFacility != null
                        ? OwnerTodoPanel(
                            loader: OwnerTodoLoader(
                              branches:
                                  dependencies.adminFacility!.branchRepository,
                              payments: dependencies.adminPaymentRepository,
                              refunds: dependencies.adminRefunds,
                              bookings: dependencies.adminBookings,
                            ),
                            onReceipts: (id) =>
                                context.push('/admin/branches/$id/payments'),
                            onRefunds: (id) =>
                                context.push('/admin/branches/$id/refunds'),
                            onToday: () => context.go('/admin/bookings'),
                          )
                        : null,
                  ),
          ),
          FcRoute(
            path: AppRoutes.catalog,
            builder: (context, state) => MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) => CatalogListBloc<CourtType>(
                    load: ListCourtTypes(catalog).call,
                    delete: DeleteCourtType(catalog).call,
                    idOf: (courtType) => courtType.id,
                    deletedMessage: 'Đã xóa loại sân',
                  )..add(const CatalogRefreshed()),
                ),
                BlocProvider(
                  create: (_) => CatalogListBloc<SubscriptionPlan>(
                    load: ListSubscriptionPlans(catalog).call,
                    delete: DeleteSubscriptionPlan(catalog).call,
                    idOf: (plan) => plan.id,
                    deletedMessage: 'Đã xóa gói dịch vụ',
                  )..add(const CatalogRefreshed()),
                ),
              ],
              child: CatalogPage(
                saveCourtType: SaveCourtType(catalog),
                saveSubscriptionPlan: SaveSubscriptionPlan(catalog),
              ),
            ),
          ),
          FcRoute(
            path: AppRoutes.profile,
            builder: (context, state) => MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) => ProfileBloc(UpdateProfile(repository)),
                ),
                BlocProvider(
                  create: (_) => ChangePasswordBloc(ChangePassword(repository)),
                ),
              ],
              child: const ProfilePage(),
            ),
          ),
          FcRoute(
            path: '/profile/edit',
            builder: (context, state) => MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) => ProfileBloc(UpdateProfile(repository)),
                ),
                BlocProvider(
                  create: (_) => ChangePasswordBloc(ChangePassword(repository)),
                ),
              ],
              child: const ProfilePage(editMode: true),
            ),
          ),
          FcRoute(
            name: 'courtSlots',
            path: '/courts/:courtId/slots',
            builder: (context, state) {
              final courtId = int.tryParse(
                state.pathParameters['courtId'] ?? '',
              );
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
              final parsed = dateText == null
                  ? null
                  : DateTime.tryParse(dateText);
              const slotSocket = String.fromEnvironment('SLOT_WEBSOCKET_URL');
              return SlotPickerScreen(
                invalidations: slotSocket.isEmpty
                    ? null
                    : StompSlotInvalidations(slotSocket, courtId),
                repository: repository,
                courtId: courtId,
                courtName: state.uri.queryParameters['courtName'],
                branchName: state.uri.queryParameters['branchName'],
                onContinue:
                    dependencies.bookingRepository is! BookingCreationRepository
                    ? null
                    : (selection) {
                        try {
                          final user = authBloc.state.user;
                          if (user == null) {
                            context.push(
                              Uri(
                                path: AppRoutes.login,
                                queryParameters: {'from': state.uri.toString()},
                              ).toString(),
                            );
                            return;
                          }
                          context.push(
                            '/booking/summary',
                            extra: BookingSummaryArguments(
                              selection: bookingSelectionFromSlots(
                                selection,
                                branchName:
                                    state.uri.queryParameters['branchName'] ??
                                    'Chi nhánh đã chọn',
                                courtName:
                                    state.uri.queryParameters['courtName'] ??
                                    'Sân #$courtId',
                              ),
                              customerName: user.fullName ?? '',
                              phone: user.phone ?? '',
                              onHeld: (checkout) => context.push(
                                '/booking/confirm',
                                extra: checkout,
                              ),
                            ),
                          );
                        } on ArgumentError {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Vui lòng chọn các khung giờ liên tiếp với giá hợp lệ.',
                              ),
                            ),
                          );
                        }
                      },
                date: parsed != null && slotDateKey(parsed) == dateText
                    ? parsed
                    : null,
              );
            },
          ),
          FcRoute(
            path: AppRoutes.discover,
            builder: (context, state) => CustomerHomeScreen(
              repository: dependencies.discoveryRepository,
            ),
          ),
          FcRoute(
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
          FcRoute(
            path: '/branches/:id',
            builder: (context, state) => BranchDetailScreen(
              discoveryRepository: dependencies.discoveryRepository,
              reviews: dependencies.reviews,
              maps: dependencies.branchMaps,
              branchId: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
              branch: state.extra is Branch ? state.extra as Branch : null,
              galleryRepository:
                  dependencies.adminFacility?.branchImageRepository,
            ),
          ),
          // Màn kiểm tra kết nối BE, dùng khi phát triển.
          FcRoute(
            path: AppRoutes.health,
            builder: (context, state) => BlocProvider(
              create: (_) =>
                  HealthBloc(GetHealthStatus(dependencies.healthRepository))
                    ..add(const HealthCheckRequested()),
              child: HealthPage(config: dependencies.config),
            ),
          ),
          ...adminFacilityRoutes(
            dependencies.adminFacility,
            hasPayments: dependencies.adminPaymentRepository != null,
            hasRefunds: dependencies.adminRefunds != null,
            hasTransactions: dependencies.adminTransactions != null,
          ),
          FcRoute(
            path: AppRoutes.superAdminOverview,
            builder: (context, state) {
              final repository = dependencies.platformOverview;
              if (repository == null) return const _UnavailableScreen();
              return BlocProvider(
                create: (_) =>
                    PlatformOverviewCubit(GetPlatformOverview(repository))
                      ..load(),
                child: const SuperAdminOverviewScreen(),
              );
            },
          ),
          FcRoute(
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
          FcRoute(
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
