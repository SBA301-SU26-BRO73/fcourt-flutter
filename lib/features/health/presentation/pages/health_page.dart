import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../bloc/health_bloc.dart';

/// Màn hình mẫu: gọi API health của BE để kiểm tra kết nối.
/// Xóa hoặc thay bằng màn hình thật khi có feature đầu tiên.
class HealthPage extends StatelessWidget {
  const HealthPage({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FCOURT')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${config.env.name.toUpperCase()} · ${config.apiBaseUrl}',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              BlocBuilder<HealthBloc, HealthState>(
                builder: (context, state) => switch (state) {
                  HealthInitial() || HealthLoading() =>
                    const CircularProgressIndicator(),
                  HealthSuccess(:final status) => _Result(
                      icon: status.isUp ? Icons.check_circle : Icons.error,
                      color: status.isUp ? Colors.green : Colors.orange,
                      text: 'Máy chủ: ${status.status}',
                    ),
                  HealthFailure(:final message) => _Result(
                      icon: Icons.cloud_off,
                      color: Theme.of(context).colorScheme.error,
                      text: message,
                    ),
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () =>
                    context.read<HealthBloc>().add(const HealthCheckRequested()),
                icon: const Icon(Icons.refresh),
                label: const Text('Kiểm tra lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 48),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center),
      ],
    );
  }
}
