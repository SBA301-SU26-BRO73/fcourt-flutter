import 'package:fcourt/app/app.dart';
import 'package:fcourt/app/app_dependencies.dart';
import 'package:fcourt/core/config/app_config.dart';
import 'package:fcourt/features/health/domain/entities/health_status.dart';
import 'package:fcourt/features/health/domain/repositories/health_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeHealthRepository implements HealthRepository {
  @override
  Future<HealthStatus> check() async => const HealthStatus('ok');
}

void main() {
  testWidgets('app khởi động và hiển thị kết quả health', (tester) async {
    await tester.pumpWidget(
      FcourtApp(
        dependencies: AppDependencies(
          config: const AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://test'),
          healthRepository: _FakeHealthRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FCOURT'), findsOneWidget);
    expect(find.text('Máy chủ: ok'), findsOneWidget);
  });
}
