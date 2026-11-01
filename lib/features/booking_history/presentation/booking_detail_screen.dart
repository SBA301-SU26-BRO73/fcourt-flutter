import '../domain/cancellation.dart';
import 'cancel_booking_dialog.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/failure.dart';
import '../domain/booking.dart';

class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({
    super.key,
    required this.repository,
    required this.id,
    this.onTicket,
    this.cancellation,
    this.onRefund,
  });
  final BookingRepository repository;
  final int id;
  final ValueChanged<int>? onTicket;
  final CancellationRepository? cancellation;
  final ValueChanged<int>? onRefund;
  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  Booking? _booking;
  CancellationPolicy? _policy;
  String? _error;
  int _generation = 0;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(BookingDetailScreen old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) _load();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _booking = null;
      _policy = null;
    });
    try {
      final result = await widget.repository.detail(widget.id);
      if (mounted && generation == _generation) {
        setState(() => _booking = result);
        if (widget.cancellation != null &&
            {
              'PENDING_PAYMENT',
              'AWAITING_CONFIRMATION',
              'CONFIRMED',
            }.contains(result.status)) {
          final policy = await widget.cancellation!.quote(widget.id);
          if (mounted && generation == _generation) {
            setState(() => _policy = policy);
          }
        }
      }
    } on Failure catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _cancel() async {
    final policy = _policy;
    if (policy == null || !policy.allowed || widget.cancellation == null) {
      return;
    }
    final id = widget.id;
    final result = await showDialog<Booking>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CancelBookingDialog(
        id: id,
        repository: widget.cancellation!,
        policy: policy,
      ),
    );
    if (!mounted || id != widget.id) return;
    if (result != null) {
      setState(() {
        _booking = result;
        _policy = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã hủy đặt sân')));
    } else {
      await _load();
    }
  }

  Future<void> _open(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      /* Display a retryable message below. */
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa mở được ứng dụng. Vui lòng thử lại.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết đặt sân')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null) ...[
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
          if (b != null) ...[
            Text(
              b.branchName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(b.courtName),
            Text('Mã đơn: ${b.code}'),
            Text(b.label),
            Text('${b.date} · ${b.slots.join(', ')}'),
            Text(
              NumberFormat.currency(
                locale: 'vi_VN',
                symbol: 'đ',
                decimalDigits: 0,
              ).format(b.amount),
            ),
            Text(
              'Thanh toán: ${switch (b.paymentStatus) {
                'CONFIRMED' => 'Đã thanh toán',
                'REJECTED' => 'Bị từ chối',
                'PENDING' => 'Chờ duyệt',
                _ => 'Chưa ghi nhận',
              }}',
            ),
            if (b.address != null) ...[
              Text(b.address!),
              OutlinedButton.icon(
                onPressed: () => _open(
                  Uri.https('www.google.com', '/maps/search/', {
                    'api': '1',
                    'query': b.address!,
                  }),
                ),
                icon: const Icon(Icons.map),
                label: const Text('Chỉ đường đến sân'),
              ),
            ],
            if (b.phone != null &&
                RegExp(r'^\+?[0-9]{9,15}$').hasMatch(b.phone!))
              TextButton.icon(
                onPressed: () => _open(Uri(scheme: 'tel', path: b.phone)),
                icon: const Icon(Icons.phone),
                label: Text('Liên hệ chủ sân: ${b.phone}'),
              ),
            if (_policy != null && !_policy!.allowed) Text(_policy!.reason),
            if (_policy?.allowed == true)
              OutlinedButton(
                onPressed: _cancel,
                child: const Text('Hủy đặt sân'),
              ),
            if (b.status == 'CANCELLED' &&
                b.paymentStatus == 'CONFIRMED' &&
                widget.onRefund != null)
              FilledButton(
                onPressed: () => widget.onRefund!(b.id),
                child: const Text('Yêu cầu / theo dõi hoàn tiền'),
              ),
            if (b.hasTicket && widget.onTicket != null)
              FilledButton.icon(
                onPressed: () => widget.onTicket!(b.id),
                icon: const Icon(Icons.qr_code),
                label: const Text('Xuất trình vé QR'),
              ),
          ],
        ],
      ),
    );
  }
}
