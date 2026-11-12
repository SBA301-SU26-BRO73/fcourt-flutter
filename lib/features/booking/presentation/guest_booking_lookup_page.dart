import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/wp3b_widgets.dart';
import '../../../core/error/failure.dart';
import '../../payment/presentation/widgets/payment_parts.dart';
import '../../../core/storage/guest_booking_store.dart';
import '../domain/entities/guest_booking_lookup.dart';
import '../domain/repositories/guest_booking_lookup_repository.dart';

class GuestBookingLookupPage extends StatefulWidget {
  const GuestBookingLookupPage({
    super.key,
    required this.repository,
    this.store,
  });
  final GuestBookingLookupRepository? repository;

  /// Đơn gần nhất của khách trên máy này; điền sẵn mã đơn và SĐT.
  final GuestBookingStore? store;

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
  void initState() {
    super.initState();
    _restoreSaved();
  }

  Future<void> _restoreSaved() async {
    final session = await widget.store?.read();
    if (!mounted || session == null) return;
    if (_code.text.isEmpty && _phone.text.isEmpty) {
      _code.text = session.bookingCode ?? '';
      _phone.text = session.phone;
    }
  }

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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            'Nhập mã đơn và số điện thoại đã dùng khi đặt sân.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                Wp3bField(
                  'Mã đơn',
                  child: TextFormField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'FC12345678',
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nhập mã đơn'
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Wp3bField(
                  'Số điện thoại',
                  child: TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '0912345678',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nhập số điện thoại'
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Wp3bAction(
                  'Tra cứu',
                  busy: _loading,
                  onPressed: _loading ? null : _lookup,
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
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
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
      fontSize: 11,
    );
    final tone = switch (booking.status) {
      'CANCELLED' || 'EXPIRED' => context.fc.danger,
      'CONFIRMED' || 'CHECKED_IN' || 'COMPLETED' => context.fc.success,
      _ => context.fc.warning,
    };
    return PayPanel(
      padding: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mã đơn: ${booking.bookingCode}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TintTag(_statusLabel(booking.status), tone: tone),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            booking.courtName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            booking.branchAddress == null
                ? booking.branchName
                : '${booking.branchName}\n${booking.branchAddress}',
            style: muted,
          ),
          const SizedBox(height: 6),
          Text('$date · $timeRange', style: muted),
          Divider(height: 29, thickness: 1, color: colors.outlineVariant),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Trạng thái: ${_statusLabel(booking.status)}',
                  style: muted,
                ),
              ),
              Text(
                amount,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          if (booking.checkInCode != null &&
              booking.checkInCode!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Mã check-in', style: muted),
            const SizedBox(height: 4),
            SelectableText(
              booking.checkInCode!,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ],
        ],
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
