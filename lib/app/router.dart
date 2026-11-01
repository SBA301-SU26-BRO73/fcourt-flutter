import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'app_dependencies.dart';
import 'auth_redirect.dart';

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
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshListenable,
    redirect: (context, state) =>
        authRedirect(authBloc.state.status, state.matchedLocation, role: authBloc.state.role),
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
      // Màn kiểm tra kết nối BE, dùng khi phát triển.
      GoRoute(
        path: AppRoutes.health,
        builder: (context, state) => BlocProvider(
          create: (_) => HealthBloc(GetHealthStatus(dependencies.healthRepository))
            ..add(const HealthCheckRequested()),
          child: HealthPage(config: dependencies.config),
        ),
      ),
    ],
  );
}
