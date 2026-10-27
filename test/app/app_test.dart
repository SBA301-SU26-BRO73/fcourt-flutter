import 'package:fcourt/app/app.dart';
import 'package:fcourt/app/app_dependencies.dart';
import 'package:fcourt/core/config/app_config.dart';
import 'package:fcourt/features/health/domain/entities/health_status.dart';
import 'package:fcourt/features/health/domain/repositories/health_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';

class _FakeHealthRepository implements HealthRepository {
  @override
  Future<HealthStatus> check() async => const HealthStatus('ok');
}

class _FakeDiscoveryRepository implements DiscoveryRepository {
  @override
  Future<BranchPage> search({
    String query = '',
    DiscoverySport? sport,
    int page = 0,
  }) async =>
      const BranchPage(branches: [], page: 0, totalPages: 0, totalElements: 0);
}

void main() {
  testWidgets('app opens discovery home and preserves health route', (
    tester,
  ) async {
    await tester.pumpWidget(
      FcourtApp(
        dependencies: AppDependencies(
          config: const AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://test'),
          healthRepository: _FakeHealthRepository(),
          discoveryRepository: _FakeDiscoveryRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FCOURT'), findsOneWidget);
    expect(find.text('Ra sân. Hết mình.'), findsOneWidget);
    await tester.tap(find.byTooltip('Kiểm tra kết nối'));
    await tester.pumpAndSettle();
    expect(find.text('Máy chủ: ok'), findsOneWidget);
  });
}
