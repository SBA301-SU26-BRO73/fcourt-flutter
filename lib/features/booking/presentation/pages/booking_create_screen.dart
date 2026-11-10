import 'package:flutter/material.dart';

import '../../domain/entities/booking_hold.dart';
import '../../domain/repositories/booking_creation_repository.dart';
import '../../../payment/domain/entities/payment_checkout.dart';

/// Creates one server-authoritative booking before opening payment.
class BookingCreateScreen extends StatefulWidget {
  const BookingCreateScreen({
    super.key,
    required this.repository,
    required this.checkout,
    required this.onCreated,
    required this.onHistory,
  });
  final BookingCreationRepository repository;
  final BookingCheckout checkout;
  final ValueChanged<CheckoutArguments> onCreated;
  final VoidCallback onHistory;
  @override
  State<BookingCreateScreen> createState() => _BookingCreateScreenState();
}

class _BookingCreateScreenState extends State<BookingCreateScreen> {
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _create();
  }

  Future<void> _create() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final id = await widget.repository.createBooking(widget.checkout);
      if (!mounted) return;
      widget.onCreated(
        CheckoutArguments(
          bookingId: id,
          holdToken: widget.checkout.hold.token,
          promoCode: widget.checkout.promoCode,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is BookingFailure ? error.message : 'Chưa xác nhận được kết quả tạo đơn. Vui lòng thử lại hoặc kiểm tra lịch sử đặt sân.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Xác nhận đặt sân')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_loading) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    'Đang tạo đơn đặt sân…',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Số tiền thanh toán sẽ được xác nhận từ hệ thống.',
                  ),
                ] else ...[
                  Icon(
                    Icons.info_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _create,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại cùng yêu cầu'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: widget.onHistory,
                    child: const Text('Kiểm tra lịch sử đặt sân'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
