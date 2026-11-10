import 'dart:async';
import 'dart:math' as math;

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
    this.onSupport,
    this.onRetryReceipt,
    this.onHome,
    this.onViewBooking,
  });
  final ReceiptRepository repository;
  final ReceiptPicker picker;
  final CheckoutArguments arguments;
  final VoidCallback onConfirmed;
  final VoidCallback? onSupport, onRetryReceipt;

  /// Leaves the payment flow once the receipt is sent. Going back would reopen
  /// the VietQR checkout, whose hold countdown then reads as an expired booking.
  final VoidCallback? onHome, onViewBooking;
  @override
  State<PaymentWaitingScreen> createState() => _PaymentWaitingScreenState();
}

class _PaymentWaitingScreenState extends State<PaymentWaitingScreen>
    with WidgetsBindingObserver {
  late ReceiptSession _session;
  ReceiptImage? _image;
  PaymentReceipt? _receipt;
  Timer? _timer, _limitTimer;
  DateTime? _deadline;
  bool _timedOut = false, _rejectionShown = false;
  int _failures = 0;
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
    _limitTimer?.cancel();
    _deadline = null;
    _timedOut = false;
    _rejectionShown = false;
    _failures = 0;
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
    _limitTimer?.cancel();
    _session.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    _timer?.cancel();
    if (!_paused && _deadline != null && !DateTime.now().isBefore(_deadline!)) {
      _stopPolling();
    }
    if (!_paused && !_timedOut) unawaited(_poll());
  }

  bool get _terminal =>
      _receipt != null && _receipt!.status != ReceiptStatus.pending;
  void _accept(PaymentReceipt? receipt) {
    setState(() {
      _receipt = receipt;
      _loading = false;
      _error = null;
      _failures = 0;
    });
    if (receipt?.status == ReceiptStatus.pending && _deadline == null) {
      _deadline = DateTime.now().add(const Duration(minutes: 10));
      _limitTimer = Timer(const Duration(minutes: 10), _stopPolling);
    }
    if (receipt != null && receipt.status != ReceiptStatus.pending) {
      _limitTimer?.cancel();
    }
    if (receipt?.status == ReceiptStatus.rejected &&
        !_rejectionShown &&
        (widget.onSupport != null || widget.onRetryReceipt != null)) {
      _rejectionShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showRejected();
      });
    }
    if (receipt?.status == ReceiptStatus.confirmed && !_navigated && !_paused) {
      _navigated = true;
      widget.onConfirmed();
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (mounted && !_paused && !_timedOut && !_terminal && _receipt != null) {
      final seconds = math.min(30, 4 * (1 << math.min(_failures, 3)));
      _timer = Timer(Duration(seconds: seconds), _poll);
    }
  }

  void _stopPolling() {
    if (!mounted || _terminal || _timedOut) return;
    _timer?.cancel();
    _limitTimer?.cancel();
    _generation++;
    _session.close();
    setState(() {
      _timedOut = true;
      _busy = false;
      _loading = false;
    });
  }

  Future<void> _manual() async {
    if (_busy) return;
    _session.close();
    _session = widget.repository.open(widget.arguments);
    await _poll(manual: true);
  }

  Future<void> _showRejected() => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Biên lai bị từ chối'),
      content: Text(
        _receipt?.rejectionReason ?? 'Vui lòng liên hệ chủ sân để được hỗ trợ.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Đóng'),
        ),
        if (widget.onRetryReceipt != null)
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              widget.onRetryReceipt!();
            },
            child: const Text('Tải lại biên lai khác'),
          ),
        if (widget.onSupport != null)
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              widget.onSupport!();
            },
            child: const Text('Liên hệ hỗ trợ'),
          ),
      ],
    ),
  );
  Future<void> _poll({bool manual = false}) async {
    if (_busy || _paused || (_timedOut && !manual)) return;
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
          _failures++;
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
    final submitted = _receipt != null;
    final leave = widget.onHome;
    return PopScope(
      canPop: !submitted || leave == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && submitted) leave?.call();
      },
      child: _scaffold(context, pending, submitted),
    );
  }

  Widget _scaffold(BuildContext context, bool pending, bool submitted) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biên lai thanh toán'),
        leading: submitted && widget.onHome != null
            ? IconButton(
                tooltip: 'Về trang chủ',
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onHome,
              )
            : null,
      ),
      bottomNavigationBar: submitted &&
              (widget.onHome != null || widget.onViewBooking != null)
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.onHome != null)
                      FilledButton.icon(
                        key: const ValueKey('receipt-home'),
                        onPressed: widget.onHome,
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('Về trang chủ'),
                      ),
                    if (widget.onHome != null && widget.onViewBooking != null)
                      const SizedBox(height: 10),
                    if (widget.onViewBooking != null)
                      OutlinedButton.icon(
                        key: const ValueKey('receipt-booking'),
                        onPressed: widget.onViewBooking,
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Xem đơn đặt sân'),
                      ),
                  ],
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_receipt != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        for (int step = 0; step < 3; step++)
                          Expanded(
                            child: Column(
                              children: [
                                Icon(
                                  step == 2
                                      ? Icons.check_circle
                                      : Icons.radio_button_checked,
                                  color:
                                      step < 2 ||
                                          _receipt?.status ==
                                              ReceiptStatus.confirmed
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                Text(
                                  [
                                    'Đã gửi biên lai',
                                    'Đang đối soát',
                                    'Xác nhận thành công',
                                  ][step],
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                if (_timedOut) ...[
                  const Text(
                    'Đã tạm dừng tự kiểm tra sau 10 phút để tiết kiệm pin. Đơn vẫn đang chờ duyệt.',
                  ),
                  TextButton(
                    onPressed: _busy ? null : _manual,
                    child: const Text('Kiểm tra thủ công'),
                  ),
                ],
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
                  if (_receipt!.status == ReceiptStatus.rejected &&
                      widget.onSupport != null)
                    TextButton(
                      onPressed: _showRejected,
                      child: const Text('Xem hỗ trợ thanh toán'),
                    ),
                ] else ...[
                  const Text(
                    'Chụp hoặc chọn ảnh biên lai chuyển khoản. Ảnh sẽ được nén trước khi gửi (tối đa 5MB).',
                  ),
                  const SizedBox(height: 16),
                  if (_image != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(
                          _image!.bytes,
                          height: 240,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Text('Chưa xem trước được ảnh'),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _pick(true),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Chụp ảnh'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _pick(false),
                          icon: const Icon(Icons.photo),
                          label: Text(
                            _image == null ? 'Chọn ảnh' : 'Chọn ảnh khác',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_busy) ...[
                    LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    onPressed: _busy || _image == null ? null : _upload,
                    icon: const Icon(Icons.upload),
                    label: const Text('Gửi biên lai'),
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
