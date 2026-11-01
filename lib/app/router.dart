import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
import '../features/health/domain/usecases/get_health_status.dart';
import '../features/health/presentation/bloc/health_bloc.dart';
import '../features/health/presentation/pages/health_page.dart';
import 'app_dependencies.dart';
import 'auth_redirect.dart';
import '../src/features/customer_discovery/domain/discovery_repository.dart';
import '../src/features/customer_discovery/presentation/discovery_cubit.dart';
import '../src/features/customer_discovery/presentation/screens/customer_home_screen.dart';
import '../src/features/customer_discovery/presentation/screens/branch_list_screen.dart';
import '../src/features/customer_discovery/presentation/screens/branch_detail_screen.dart';
import '../src/features/customer_slots/presentation/slot_picker_screen.dart';
import '../src/features/customer_slots/domain/court_slot.dart';

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
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshListenable,
    redirect: (context, state) =>
        authRedirect(authBloc.state.status, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => BlocProvider(
          create: (_) => LoginBloc(Login(repository)),
          child: const LoginPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.registerCustomer,
        builder: (context, state) => BlocProvider(
          create: (_) => RegisterBloc(
            RegisterCustomer(repository),
            RegisterCourtOwner(repository),
          ),
          child: const RegisterCustomerPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.registerOwner,
        builder: (context, state) => BlocProvider(
          create: (_) => RegisterBloc(
            RegisterCustomer(repository),
            RegisterCourtOwner(repository),
          ),
          child: RegisterOwnerPage(picker: dependencies.documentPicker),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => BlocProvider(
          create: (_) => ForgotPasswordBloc(RequestPasswordReset(repository)),
          child: const ForgotPasswordPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => BlocProvider(
          create: (_) => ResetPasswordBloc(ResetPassword(repository)),
          child: ResetPasswordPage(initialToken: state.uri.queryParameters['token']),
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => ProfileBloc(UpdateProfile(repository))),
            BlocProvider(create: (_) => ChangePasswordBloc(ChangePassword(repository))),
          ],
          child: const ProfilePage(),
        ),
      ),
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
        path: AppRoutes.discover,
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
      // Màn kiểm tra kết nối BE, dùng khi phát triển.
      GoRoute(
        path: AppRoutes.health,
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
