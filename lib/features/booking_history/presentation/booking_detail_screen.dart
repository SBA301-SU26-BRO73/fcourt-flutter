import '../domain/cancellation.dart';
import 'cancel_booking_dialog.dart';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/wp3b_widgets.dart';
import '../../payment/domain/entities/payment_checkout.dart';
import '../../payment/domain/repositories/ticket_repository.dart';
import '../../payment/presentation/widgets/ticket_panel.dart';
import 'booking_style.dart';
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
    this.ticketRepository,
    this.ticketSaver,
  });
  final BookingRepository repository;
  final int id;
  final ValueChanged<int>? onTicket;
  final CancellationRepository? cancellation;
  final ValueChanged<int>? onRefund;
  final Future<bool> Function(int)? onReview;

  /// Opens checkout again for an unpaid booking (transfer + receipt upload).
  final ValueChanged<int>? onPay;

  /// With both set, the entry ticket (QR) is shown on this page; without them
  /// [onTicket] opens it elsewhere.
  final TicketRepository? ticketRepository;
  final TicketSaver? ticketSaver;
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
  TicketLoader? _ticket;
  String? _shownSave;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _ticketChanged() {
    final message = _ticket?.saveMessage;
    if (message != null && message != _shownSave && mounted) {
      _shownSave = message;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
    if (_ticket?.saving == true) _shownSave = null;
  }

  void _syncTicket(Booking? b) {
    final wanted =
        b != null &&
        b.hasTicket &&
        widget.ticketRepository != null &&
        widget.ticketSaver != null;
    if (!wanted) {
      _ticket?.removeListener(_ticketChanged);
      _ticket?.dispose();
      _ticket = null;
      return;
    }
    final args = CheckoutArguments(bookingId: b.id);
    if (_ticket == null) {
      _ticket = TicketLoader(
        repository: widget.ticketRepository!,
        saver: widget.ticketSaver!,
        arguments: args,
      )..addListener(_ticketChanged);
    } else {
      _ticket!.update(args);
    }
  }

  @override
  void didUpdateWidget(BookingDetailScreen old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) _load();
  }

  @override
  void dispose() {
    _generation++;
    _ticket?.removeListener(_ticketChanged);
    _ticket?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _booking = null;
      _policy = null;
      _syncTicket(null);
    });
    try {
      final result = await widget.repository.detail(widget.id);
      if (mounted && generation == _generation) {
        _syncTicket(result);
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
      _syncTicket(result);
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

  bool get _inlineTicket =>
      widget.ticketRepository != null && widget.ticketSaver != null;

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết đơn')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_error != null) ...[
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ],
                if (b != null) ..._content(context, b, theme, colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    Booking b,
    ThemeData theme,
    ColorScheme colors,
  ) {
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
      fontSize: 11,
    );
    final payment = switch (b.paymentStatus) {
      'CONFIRMED' => 'Đã thanh toán',
      'REJECTED' => 'Bị từ chối',
      'PENDING' when b.status == 'PENDING_PAYMENT' => 'Chưa gửi biên lai',
      'PENDING' => 'Chờ duyệt',
      _ => 'Chưa ghi nhận',
    };
    final paymentTone = switch (b.paymentStatus) {
      'CONFIRMED' => context.fc.success,
      'REJECTED' => context.fc.danger,
      'PENDING' => context.fc.warning,
      _ => context.fc.neutral,
    };
    final date = DateTime.tryParse(b.date);
    final phoneOk =
        b.phone != null && RegExp(r'^\+?[0-9]{9,15}$').hasMatch(b.phone!);
    final showTicket = b.hasTicket && _inlineTicket;
    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 17),
        child: Row(
          children: [
            TintTag(b.tagLabel, tone: b.tone(context), icon: b.statusIcon),
            const SizedBox(width: 8),
            if (b.paymentStatus != 'CONFIRMED') ...[
              Flexible(
                child: TintTag('Thanh toán: $payment', tone: paymentTone),
              ),
              const SizedBox(width: 8),
            ],
            const Spacer(),
            Text('#${b.code}', style: muted?.copyWith(fontSize: 12)),
          ],
        ),
      ),
      ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: SizedBox(
          height: 156,
          child: Stack(
            fit: StackFit.expand,
            children: [
              SportPhoto(kind: b.sportKind),
              if (b.sportAndCourt.isNotEmpty)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: _PhotoChip(kind: b.sportKind, label: b.sportAndCourt),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        b.branchName,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontSize: 20,
          letterSpacing: -.6,
        ),
      ),
      if (b.address != null) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.place_outlined,
              size: 15,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(b.address!, style: muted)),
          ],
        ),
      ],
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 19),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            _FactItem(
              icon: Icons.event_available_outlined,
              label: date == null ? 'Ngày chơi' : weekdayName(date),
              value: b.dateText,
            ),
            _FactItem(
              icon: Icons.schedule,
              label: 'Giờ chơi',
              value: mergeSlotRanges(b.slots).join(' · '),
            ),
            _FactItem(
              icon: Icons.payments_outlined,
              label: 'Tổng tiền',
              value: b.amountText,
            ),
          ],
        ),
      ),
      if (showTicket) ...[
        TicketCard(loader: _ticket!, courtName: b.courtName),
        const SizedBox(height: 17),
        ListenableBuilder(
          listenable: _ticket!,
          builder: (context, _) => FilledButton(
            onPressed: _ticket!.ticket == null || _ticket!.saving
                ? null
                : _ticket!.save,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.download, size: 18),
                const SizedBox(width: 8),
                Text(_ticket!.saving ? 'Đang lưu…' : 'Lưu vé'),
              ],
            ),
          ),
        ),
      ] else if (b.hasTicket && widget.onTicket != null)
        FilledButton.icon(
          onPressed: () => widget.onTicket!(b.id),
          icon: const Icon(Icons.qr_code),
          label: const Text('Xuất trình vé QR'),
        ),
      if (_canPay(b))
        FilledButton(
          key: const ValueKey('booking-pay'),
          onPressed: () => widget.onPay!(b.id),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Thanh toán · Gửi biên lai'),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward, size: 18),
            ],
          ),
        ),
      if (b.status == 'COMPLETED' && widget.onReview != null && !_reviewed)
        OutlinedButton.icon(
          onPressed: _reviewing
              ? null
              : () async {
                  setState(() => _reviewing = true);
                  try {
                    final submitted = await widget.onReview!(b.id);
                    if (submitted && mounted) setState(() => _reviewed = true);
                  } finally {
                    if (mounted) setState(() => _reviewing = false);
                  }
                },
          icon: const Icon(Icons.star_outline),
          label: const Text('Đánh giá sân'),
        ),
      if (b.address != null || phoneOk)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              if (b.address != null)
                TextButton.icon(
                  onPressed: () => _open(
                    Uri.https('www.google.com', '/maps/search/', {
                      'api': '1',
                      'query': b.address!,
                    }),
                  ),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Chỉ đường đến sân'),
                ),
              if (phoneOk)
                TextButton.icon(
                  onPressed: () => _open(Uri(scheme: 'tel', path: b.phone)),
                  icon: const Icon(Icons.phone_outlined, size: 18),
                  label: Text('Liên hệ chủ sân: ${b.phone}'),
                ),
            ],
          ),
        ),
      if (_policy != null && !_policy!.allowed)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_policy!.reason, style: muted),
        ),
      if (_policy?.allowed == true)
        Center(
          child: TextButton(
            onPressed: _cancel,
            style: TextButton.styleFrom(
              foregroundColor: colors.error,
              minimumSize: const Size(0, 48),
            ),
            child: const Text('Hủy đơn'),
          ),
        ),
      if (b.status == 'CANCELLED' &&
          b.paymentStatus == 'CONFIRMED' &&
          widget.onRefund != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: FilledButton(
            onPressed: () => widget.onRefund!(b.id),
            child: const Text('Yêu cầu / theo dõi hoàn tiền'),
          ),
        ),
    ];
  }
}

/// Mock-up ".play-date" item: accent icon, 10dp label over 12/700 value.
class _FactItem extends StatelessWidget {
  const _FactItem({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 21, color: colors.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}

class _PhotoChip extends StatelessWidget {
  const _PhotoChip({required this.kind, required this.label});
  final SportKind kind;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SportIcon(kind, size: 13, color: const Color(0xFF354064)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF354064),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
