import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/wp3b_widgets.dart';
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

  Future<void> _torch() async {
    try {
      await _camera.toggleTorch();
    } on MobileScannerException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thiết bị chưa hỗ trợ đèn flash')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _camera,
                  onDetect: _detected,
                  errorBuilder: (context, error) => ColoredBox(
                    color: colors.surfaceContainerLow,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Wp3bBadge(Icons.no_photography_outlined),
                            const SizedBox(height: Gap.lg),
                            Text(
                              _cameraError ?? 'Không thể dùng camera. Cho phép quyền camera rồi thử lại.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: Gap.md),
                            FilledButton(
                              onPressed: _start,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.sheet),
                      border: Border.all(color: colors.primary, width: 4),
                    ),
                  ),
                ),
                Positioned(
                  top: top + 8,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      CircleIconButton(
                        icon: Icons.arrow_back,
                        tooltip: 'Quay lại',
                        onImage: true,
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      const Spacer(),
                      CircleIconButton(
                        icon: Icons.flash_on,
                        tooltip: 'Bật/tắt đèn flash',
                        onImage: true,
                        onPressed: _torch,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(Radii.sheet),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quét vé nhận sân',
                      style: text.titleLarge?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      'Đưa mã QR vào khung. Kiểm tra thông tin vé trước khi xác nhận nhận sân.',
                      style: text.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
