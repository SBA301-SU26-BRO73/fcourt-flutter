import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/error/failure.dart';
import '../domain/entities/guest_booking_lookup.dart';
import '../domain/repositories/guest_booking_lookup_repository.dart';

class GuestBookingLookupPage extends StatefulWidget {
  const GuestBookingLookupPage({super.key, required this.repository});
  final GuestBookingLookupRepository? repository;

  @override
  State<GuestBookingLookupPage> createState() => _GuestBookingLookupPageState();
}

class _GuestBookingLookupPageState extends State<GuestBookingLookupPage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _phone = TextEditingController();
  GuestBookingLookup? _booking;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    if (!_formKey.currentState!.validate() || _loading) return;
    final repository = widget.repository;
    if (repository == null) {
      setState(() => _error = 'Tra cứu đơn hiện chưa khả dụng.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _booking = null;
    });
    try {
      final booking = await repository.lookup(_code.text, _phone.text);
      if (mounted) setState(() => _booking = booking);
    } on ServerFailure catch (failure) {
      if (!mounted) return;
      setState(
        () => _error = switch (failure.statusCode) {
          400 => 'Mã đơn hoặc số điện thoại chưa đúng định dạng.',
          404 => 'Không tìm thấy đơn. Kiểm tra lại mã đơn và số điện thoại.',
          429 => failure.message,
          _ => 'Không thể tra cứu lúc này. Vui lòng thử lại.',
        },
      );
    } on Failure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = _booking;
    return Scaffold(
      appBar: AppBar(title: const Text('Tra cứu đơn đặt sân')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Nhập mã đơn và số điện thoại đã dùng khi đặt sân.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Mã đơn',
                    hintText: 'FC12345678',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Nhập mã đơn'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Số điện thoại'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Nhập số điện thoại'
                      : null,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _lookup,
                    child: _loading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Tra cứu'),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (booking != null) ...[
            const SizedBox(height: 24),
            _GuestBookingCard(booking: booking),
          ],
        ],
      ),
    );
  }
}

class _GuestBookingCard extends StatelessWidget {
  const _GuestBookingCard({required this.booking});
  final GuestBookingLookup booking;

  @override
  Widget build(BuildContext context) {
    final timeRange = booking.slots.isEmpty
        ? ''
        : '${booking.slots.first.startTime.substring(0, 5)}–'
              '${booking.slots.last.endTime.substring(0, 5)}';
    final date = DateFormat('dd/MM/yyyy').format(booking.date);
    final amount = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    ).format(booking.totalPrice);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              booking.courtName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${booking.branchName}${booking.branchAddress == null ? '' : '\n${booking.branchAddress}'}',
            ),
            Text('$date · $timeRange'),
            Text('Mã đơn: ${booking.bookingCode}'),
            Text('Trạng thái: ${_statusLabel(booking.status)}'),
            Text('Tổng tiền: $amount'),
            if (booking.checkInCode != null &&
                booking.checkInCode!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Mã check-in',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              SelectableText(
                booking.checkInCode!,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
    'PENDING_PAYMENT' => 'Chờ thanh toán',
    'PENDING_APPROVAL' => 'Chờ duyệt',
    'CONFIRMED' => 'Đã xác nhận',
    'CHECKED_IN' => 'Đã nhận sân',
    'COMPLETED' => 'Đã hoàn thành',
    'CANCELLED' => 'Đã hủy',
    'EXPIRED' => 'Đã hết hạn',
    _ => 'Đang cập nhật',
  };
}
