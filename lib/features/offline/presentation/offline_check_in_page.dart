import 'package:flutter/material.dart';

import '../../operations/domain/schedule.dart';
import '../../operations/presentation/scanner_page.dart';
import '../../operations/presentation/manual_check_in.dart';

class OfflineCheckInPage extends StatelessWidget {
  const OfflineCheckInPage({
    super.key,
    required this.repository,
    required this.syncPanel,
    required this.onReconnect,
    required this.onLogin,
  });
  final OperationsRepository repository;
  final Widget syncPanel;
  final VoidCallback onReconnect, onLogin;

  Future<void> _check(BuildContext context, {bool manual = false}) async {
    final result = manual
        ? await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => ManualCheckIn(repository: repository),
          )
        : await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => ScannerPage(repository: repository),
            ),
          );
    if (context.mounted && result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã nhận sân OFFLINE. Đang chờ đối soát máy chủ.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nhận sân ngoại tuyến')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.wifi_off, size: 48),
          const SizedBox(height: 16),
          Text(
            'Tiếp tục nhận sân khi mất mạng',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Chỉ dùng vé đã đồng bộ đầu ca hôm nay. Phiên phải còn hạn; '
            'mỗi lượt nhận sân được lưu trên máy và chờ đối soát khi có mạng.',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _check(context),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Quét vé offline'),
          ),
          OutlinedButton.icon(
            onPressed: () => _check(context, manual: true),
            icon: const Icon(Icons.keyboard),
            label: const Text('Nhập mã vé'),
          ),
          syncPanel,
          const Divider(),
          OutlinedButton(
            onPressed: onReconnect,
            child: const Text('Kết nối lại để xác thực online'),
          ),
          TextButton(
            onPressed: onLogin,
            child: const Text('Về màn hình đăng nhập'),
          ),
        ],
      ),
    ),
  );
}
