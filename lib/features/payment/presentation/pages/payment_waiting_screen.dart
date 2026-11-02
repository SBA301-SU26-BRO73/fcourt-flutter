import 'dart:async';

import '../widgets/waiting_ripple.dart';

import 'package:flutter/material.dart';

import '../../domain/entities/payment_checkout.dart';
import '../../domain/entities/payment_receipt.dart';
import '../../domain/repositories/receipt_repository.dart';

class PaymentWaitingScreen extends StatefulWidget {
  const PaymentWaitingScreen({
    super.key,
    required this.repository,
    required this.picker,
    required this.arguments,
    required this.onConfirmed,
  });
  final ReceiptRepository repository;
  final ReceiptPicker picker;
  final CheckoutArguments arguments;
  final VoidCallback onConfirmed;
  @override
  State<PaymentWaitingScreen> createState() => _PaymentWaitingScreenState();
}

class _PaymentWaitingScreenState extends State<PaymentWaitingScreen>
    with WidgetsBindingObserver {
  late ReceiptSession _session;
  ReceiptImage? _image;
  PaymentReceipt? _receipt;
  Timer? _timer;
  String? _error;
  bool _busy = false, _loading = true, _paused = false, _navigated = false;
  double _progress = 0;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _session = widget.repository.open(widget.arguments);
    _loading = true;
    _receipt = null;
    _image = null;
    _error = null;
    _busy = false;
    _navigated = false;
    unawaited(_poll());
    unawaited(_recover(_generation));
  }

  bool _active(int generation) => mounted && generation == _generation;
  Future<void> _recover(int generation) async {
    try {
      final image = await widget.picker.recover();
      if (_active(generation) && image != null) setState(() => _image = image);
    } on PaymentFailure catch (e) {
      if (_active(generation)) setState(() => _error = e.message);
    }
  }

  @override
  void didUpdateWidget(PaymentWaitingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.arguments.bookingId != widget.arguments.bookingId ||
        oldWidget.arguments.holdToken != widget.arguments.holdToken) {
      _generation++;
      _timer?.cancel();
      _session.close();
      _start();
    }
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    _session.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    _timer?.cancel();
    if (!_paused) unawaited(_poll());
  }

  bool get _terminal =>
      _receipt != null && _receipt!.status != ReceiptStatus.pending;
  void _accept(PaymentReceipt? receipt) {
    setState(() {
      _receipt = receipt;
      _loading = false;
      _error = null;
    });
    if (receipt?.status == ReceiptStatus.confirmed && !_navigated && !_paused) {
      _navigated = true;
      widget.onConfirmed();
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (mounted && !_paused && !_terminal && _receipt != null) {
      _timer = Timer(const Duration(seconds: 4), _poll);
    }
  }

  Future<void> _poll() async {
    if (_busy || _paused) return;
    if (_receipt?.status == ReceiptStatus.confirmed) {
      _accept(_receipt);
      return;
    }
    if (_terminal) return;
    _timer?.cancel();
    final generation = _generation;
    _busy = true;
    try {
      final receipt = await _session.status();
      if (_active(generation)) _accept(receipt);
    } on PaymentFailure catch (e) {
      if (_active(generation)) {
        setState(() {
          _error = e.message;
          _loading = false;
          if (e.expired) {
            _receipt = PaymentReceipt(
              id: 0,
              bookingId: widget.arguments.bookingId,
              status: ReceiptStatus.cancelled,
            );
          }
        });
      }
    } finally {
      if (_active(generation)) {
        setState(() => _busy = false);
        _schedule();
      }
    }
  }

  Future<void> _pick(bool camera) async {
    if (_busy) return;
    final generation = _generation;
    setState(() => _busy = true);
    try {
      final image = await widget.picker.pick(camera: camera);
      if (_active(generation) && image != null) {
        setState(() {
          _image = image;
          _error = null;
        });
      }
    } on PaymentFailure catch (e) {
      if (_active(generation)) setState(() => _error = e.message);
    } finally {
      if (_active(generation)) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    if (_image == null || _busy) return;
    final generation = _generation;
    _timer?.cancel();
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    try {
      final receipt = await _session.upload(_image!, (p) {
        if (_active(generation)) setState(() => _progress = p);
      });
      if (_active(generation)) _accept(receipt);
    } on PaymentFailure catch (e) {
      if (_active(generation)) setState(() => _error = e.message);
    } finally {
      if (_active(generation)) {
        setState(() => _busy = false);
        _schedule();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _receipt?.status == ReceiptStatus.pending;
    return Scaffold(
      appBar: AppBar(title: const Text('Biên lai thanh toán')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (pending) ...[
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: WaitingRipple()),
                  ),
                  const Text(
                    'Đã gửi biên lai · Đang chờ chủ sân xác nhận',
                    textAlign: TextAlign.center,
                  ),
                  const Text(
                    'Bạn có thể rời màn hình và quay lại để xem trạng thái.',
                    textAlign: TextAlign.center,
                  ),
                ] else if (_terminal) ...[
                  Icon(
                    _receipt!.status == ReceiptStatus.confirmed
                        ? Icons.check_circle
                        : Icons.info_outline,
                    size: 64,
                  ),
                  Text(
                    _receipt!.status == ReceiptStatus.confirmed
                        ? 'Thanh toán đã xác nhận'
                        : 'Thanh toán đã bị từ chối hoặc hủy',
                  ),
                  if (_receipt!.rejectionReason != null)
                    Text(_receipt!.rejectionReason!),
                ] else ...[
                  const Text(
                    'Chụp hoặc chọn ảnh biên lai chuyển khoản. Ảnh sẽ được nén trước khi gửi (tối đa 5MB).',
                  ),
                  if (_image != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Image.memory(
                        _image!.bytes,
                        height: 240,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const Text('Chưa xem trước được ảnh'),
                      ),
                    ),
                  Wrap(
                    spacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _pick(true),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Chụp ảnh'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _pick(false),
                        icon: const Icon(Icons.photo),
                        label: const Text('Chọn ảnh'),
                      ),
                    ],
                  ),
                  if (_busy)
                    LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                    ),
                  FilledButton(
                    onPressed: _busy || _image == null ? null : _upload,
                    child: const Text('Gửi biên lai'),
                  ),
                ],
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _poll,
                    child: const Text('Kiểm tra lại trạng thái'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
