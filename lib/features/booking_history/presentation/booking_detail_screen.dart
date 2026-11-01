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
  });
  final BookingRepository repository;
  final int id;
  final ValueChanged<int>? onTicket;
  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  Booking? _booking;
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
    });
    try {
      final result = await widget.repository.detail(widget.id);
      if (mounted && generation == _generation) {
        setState(() => _booking = result);
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
