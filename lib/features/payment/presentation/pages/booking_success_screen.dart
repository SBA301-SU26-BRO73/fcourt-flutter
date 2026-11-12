import 'package:flutter/material.dart';

import '../../domain/entities/payment_checkout.dart';
import '../../domain/repositories/ticket_repository.dart';
import '../../../../app/theme/tokens.dart';
import '../widgets/ticket_panel.dart';
import 'ticket_brightness_scope.dart';

/// Ticket page shown after a successful payment: confirmation, the entry
/// ticket (QR), "Lưu vé" and a way to the order list.
class BookingSuccessScreen extends StatefulWidget {
  const BookingSuccessScreen({
    super.key,
    required this.repository,
    required this.saver,
    required this.arguments,
    this.onHistory,
    this.brightness,
  });
  final TicketRepository repository;
  final TicketSaver saver;
  final CheckoutArguments arguments;
  final VoidCallback? onHistory;
  final TicketBrightness? brightness;
  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen> {
  late final TicketLoader _loader = TicketLoader(
    repository: widget.repository,
    saver: widget.saver,
    arguments: widget.arguments,
  )..addListener(_onChange);
  String? _shownMessage;

  @override
  void didUpdateWidget(BookingSuccessScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loader.update(widget.arguments);
  }

  void _onChange() {
    final message = _loader.saveMessage;
    if (message != null && message != _shownMessage && mounted) {
      _shownMessage = message;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
    if (_loader.saving) _shownMessage = null;
  }

  @override
  void dispose() {
    _loader
      ..removeListener(_onChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final success = context.fc.success;
    return Scaffold(
      appBar: AppBar(title: const Text('Vé đặt sân')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListenableBuilder(
              listenable: _loader,
              builder: (context, _) {
                final ticket = _loader.ticket;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    if (ticket != null) ...[
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: success.container,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 34,
                            color: success.color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Đặt sân thành công!',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${ticket.branchName} · ${ticket.courtName}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${ticket.date} · ${ticket.slots.join(' · ')}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'Mã đơn: ${ticket.bookingCode}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    TicketCard(loader: _loader, brightness: widget.brightness),
                    if (ticket != null) ...[
                      const SizedBox(height: 17),
                      FilledButton(
                        onPressed: _loader.saving ? null : _loader.save,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.download, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _loader.saving ? 'Đang lưu…' : 'Lưu vé vào máy',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: widget.onHistory,
                        child: const Text('Xem trong lịch sử đặt sân'),
                      ),
                      if (widget.onHistory == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Lịch sử đặt sân chưa khả dụng',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
