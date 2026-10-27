import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/entities/booking_ticket.dart';
import '../../domain/entities/payment_checkout.dart';
import '../../domain/repositories/ticket_repository.dart';

class BookingSuccessScreen extends StatefulWidget {
  const BookingSuccessScreen({
    super.key,
    required this.repository,
    required this.saver,
    required this.arguments,
    this.onHistory,
  });
  final TicketRepository repository;
  final TicketSaver saver;
  final CheckoutArguments arguments;
  final VoidCallback? onHistory;
  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen>
    with WidgetsBindingObserver {
  BookingTicket? _ticket;
  String? _error;
  bool _loading = false, _saving = false, _paused = false;
  Timer? _retry;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _retry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(BookingSuccessScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.arguments.bookingId != widget.arguments.bookingId ||
        oldWidget.arguments.holdToken != widget.arguments.holdToken) {
      _generation++;
      _loading = false;
      _saving = false;
      _retry?.cancel();
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    _retry?.cancel();
    if (!_paused) _load();
  }

  Future<void> _load() async {
    if (_loading || _paused) return;
    final generation = _generation;
    _retry?.cancel();
    setState(() {
      _loading = true;
      _ticket = null;
      _error = null;
    });
    try {
      final ticket = await widget.repository.load(widget.arguments);
      if (mounted && generation == _generation) {
        setState(() => _ticket = ticket);
      }
    } on PaymentFailure catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.message);
        if (e is TicketNotReady && !_paused) {
          _retry = Timer(const Duration(seconds: 4), _load);
        }
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    final ticket = _ticket;
    if (ticket == null || _saving) return;
    final generation = _generation;
    setState(() => _saving = true);
    try {
      await widget.saver.save(ticket);
      if (mounted && generation == _generation) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu vé PNG vào thư viện ảnh')),
        );
      }
    } on PaymentFailure catch (e) {
      if (mounted && generation == _generation) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;
    return Scaffold(
      appBar: AppBar(title: const Text('Vé đặt sân')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_loading) const Center(child: CircularProgressIndicator()),
                if (_error != null) ...[
                  Text(_error!, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: _loading ? null : _load,
                    child: const Text('Tải lại vé'),
                  ),
                ],
                if (ticket != null) ...[
                  const Icon(Icons.check_circle, color: Colors.green, size: 56),
                  Text(
                    'Đặt sân thành công!',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            ticket.branchName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(ticket.courtName),
                          Text(ticket.date),
                          Text(ticket.slots.join(' · ')),
                          Text('Mã đơn: ${ticket.bookingCode}'),
                          const SizedBox(height: 12),
                          ColoredBox(
                            color: Colors.white,
                            child: Image.memory(
                              ticket.png,
                              width: 300,
                              height: 300,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.none,
                              semanticLabel: 'Mã QR check-in tại sân',
                              errorBuilder: (_, _, _) => const SizedBox(
                                height: 300,
                                child: Center(
                                  child: Text(
                                    'Chưa hiển thị được QR. Hãy tải lại vé.',
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Text('Mã check-in'),
                          SelectableText(
                            ticket.checkInCode,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Text(
                    'Đến sân đúng giờ và đưa mã QR hoặc mã check-in cho nhân viên tại quầy.',
                  ),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.download),
                    label: Text(_saving ? 'Đang lưu…' : 'Lưu vé vào máy'),
                  ),
                  OutlinedButton(
                    onPressed: widget.onHistory,
                    child: const Text('Xem trong lịch sử đặt sân'),
                  ),
                  if (widget.onHistory == null)
                    const Text(
                      'Lịch sử đặt sân chưa khả dụng',
                      textAlign: TextAlign.center,
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
