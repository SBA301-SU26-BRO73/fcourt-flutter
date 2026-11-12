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
    this.onReview,
    this.onPay,
  });
  final BookingRepository repository;
  final int id;
  final ValueChanged<int>? onTicket;
  final CancellationRepository? cancellation;
  final ValueChanged<int>? onRefund;
  final Future<bool> Function(int)? onReview;

  /// Opens checkout again for an unpaid booking (transfer + receipt upload).
  final ValueChanged<int>? onPay;
  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  Booking? _booking;
  CancellationPolicy? _policy;
  String? _error;
  int _generation = 0;
  bool _loading = false;
  bool _reviewing = false;
  bool _reviewed = false;
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

  /// Unpaid booking: the receipt has not been sent yet (once sent the booking
  /// moves to AWAITING_CONFIRMATION; a rejected receipt cancels it).
  bool _canPay(Booking b) =>
      widget.onPay != null && b.status == 'PENDING_PAYMENT';

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết đặt sân')),
      bottomNavigationBar:
          b == null ||
              !(b.hasTicket && widget.onTicket != null ||
                  _policy?.allowed == true ||
                  _canPay(b) ||
                  b.status == 'COMPLETED' && widget.onReview != null)
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_canPay(b))
                      FilledButton.icon(
                        key: const ValueKey('booking-pay'),
                        onPressed: () => widget.onPay!(b.id),
                        icon: const Icon(Icons.qr_code_2),
                        label: const Text('Thanh toán · Gửi biên lai'),
                      ),
                    if (b.hasTicket && widget.onTicket != null)
                      FilledButton.icon(
                        onPressed: () => widget.onTicket!(b.id),
                        icon: const Icon(Icons.qr_code),
                        label: const Text('Xuất trình vé QR'),
                      ),
                    if (b.status == 'COMPLETED' &&
                        widget.onReview != null &&
                        !_reviewed)
                      OutlinedButton.icon(
                        onPressed: _reviewing
                            ? null
                            : () async {
                                setState(() => _reviewing = true);
                                try {
                                  final submitted = await widget.onReview!(
                                    b.id,
                                  );
                                  if (submitted && mounted) {
                                    setState(() => _reviewed = true);
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _reviewing = false);
                                  }
                                }
                              },
                        icon: const Icon(Icons.star_outline),
                        label: const Text('Đánh giá sân'),
                      ),
                    if (_policy?.allowed == true)
                      TextButton(
                        onPressed: _cancel,
                        child: const Text('Hủy đặt sân'),
                      ),
                  ],
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null) ...[
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
          if (b != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer
                    .withValues(alpha: .45),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.branchName,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    b.courtName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    b.label,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Mã đơn: ${b.code}'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Thông tin buổi chơi',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('Ngày chơi'),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy').format(DateTime.parse(b.date)),
                    ),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Khung giờ'),
                    subtitle: Text(mergeSlotRanges(b.slots).join(' · ')),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: const Text('Tổng tiền'),
                    trailing: Text(
                      NumberFormat.currency(
                        locale: 'vi_VN',
                        symbol: 'đ',
                        decimalDigits: 0,
                      ).format(b.amount),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Thanh toán: ${switch (b.paymentStatus) {
                'CONFIRMED' => 'Đã thanh toán',
                'REJECTED' => 'Bị từ chối',
                'PENDING' when b.status == 'PENDING_PAYMENT' => 'Chưa gửi biên lai',
                'PENDING' => 'Chờ duyệt',
                _ => 'Chưa ghi nhận',
              }}',
            ),
            const SizedBox(height: 20),
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
            if (b.status == 'CANCELLED' &&
                b.paymentStatus == 'CONFIRMED' &&
                widget.onRefund != null)
              FilledButton(
                onPressed: () => widget.onRefund!(b.id),
                child: const Text('Yêu cầu / theo dõi hoàn tiền'),
              ),
          ],
        ],
      ),
    );
  }
}
