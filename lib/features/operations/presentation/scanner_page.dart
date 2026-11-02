import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../domain/schedule.dart';
import 'check_in_dialog.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key, required this.repository});
  final OperationsRepository repository;
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with WidgetsBindingObserver {
  final _camera = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handling = false;
  String? _cameraError;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _start() async {
    if (!mounted || _handling) return;
    try {
      await _camera.start();
    } on MobileScannerException {
      if (mounted) {
        setState(
          () => _cameraError = 'Không mở được camera. Kiểm tra quyền camera trong cài đặt ứng dụng.',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_camera.value.hasCameraPermission) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_start());
    } else {
      unawaited(_camera.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_camera.dispose());
    super.dispose();
  }

  Future<void> _detected(BarcodeCapture capture) async {
    if (_handling || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue?.trim();
    if (code == null || code.isEmpty || code.length > 128) return;
    _handling = true;
    await _camera.stop();
    await HapticFeedback.mediumImpact();
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CheckInDialog(repository: widget.repository, code: code),
    );
    if (!mounted) return;
    if (ok == true) {
      Navigator.pop(context, true);
      return;
    }
    _handling = false;
    await _start();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Quét vé nhận sân'),
      actions: [
        IconButton(
          tooltip: 'Bật/tắt đèn flash',
          onPressed: () async {
            try {
              await _camera.toggleTorch();
            } on MobileScannerException {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thiết bị chưa hỗ trợ đèn flash'),
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.flash_on),
        ),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: MobileScanner(
            controller: _camera,
            onDetect: _detected,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.no_photography_outlined, size: 48),
                    Text(
                      _cameraError ?? 'Không thể dùng camera. Cho phép quyền camera rồi thử lại.',
                    ),
                    TextButton(onPressed: _start, child: const Text('Thử lại')),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Đưa mã QR vào camera. Kiểm tra thông tin vé trước khi xác nhận nhận sân.',
            ),
          ),
        ),
      ],
    ),
  );
}
