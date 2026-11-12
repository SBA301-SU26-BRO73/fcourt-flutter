import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/booking_ticket.dart';
import '../../domain/entities/payment_checkout.dart';
import '../../domain/repositories/ticket_repository.dart';
import '../pages/ticket_brightness_scope.dart';

/// Loads the ticket of a booking, retries while the backend is still syncing
/// it, and saves it to the gallery. Screens listen to it and draw
/// [TicketCard].
class TicketLoader extends ChangeNotifier with WidgetsBindingObserver {
  TicketLoader({
    required this.repository,
    required this.saver,
    required this.arguments,
  }) {
    WidgetsBinding.instance.addObserver(this);
    unawaited(load());
  }

  static const _maxSyncRetries = 15;

  final TicketRepository repository;
  final TicketSaver saver;
  CheckoutArguments arguments;
  BookingTicket? ticket;
  String? error;
  bool loading = false, saving = false;
  bool _paused = false, _disposed = false;
  Timer? _retry;
  int _generation = 0, _syncRetries = 0;

  /// Message of the last save attempt (success or failure), for a snack bar.
  String? saveMessage;

  /// Points the loader at another booking (or hold token) and reloads.
  void update(CheckoutArguments next) {
    if (next.bookingId == arguments.bookingId &&
        next.holdToken == arguments.holdToken) {
      return;
    }
    arguments = next;
    _generation++;
    loading = false;
    saving = false;
    _retry?.cancel();
    unawaited(load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    _retry?.cancel();
    if (!_paused) unawaited(load());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load({bool automatic = false}) async {
    if (loading || _paused) return;
    if (!automatic) _syncRetries = 0;
    final generation = _generation;
    _retry?.cancel();
    loading = true;
    ticket = null;
    error = null;
    _notify();
    try {
      final loaded = await repository.load(arguments);
      if (!_disposed && generation == _generation) ticket = loaded;
    } on PaymentFailure catch (e) {
      if (!_disposed && generation == _generation) {
        error = e.message;
        if (e is TicketNotReady && !_paused && _syncRetries < _maxSyncRetries) {
          _syncRetries++;
          _retry = Timer(
            const Duration(seconds: 4),
            () => unawaited(load(automatic: true)),
          );
        }
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> save() async {
    final current = ticket;
    if (current == null || saving) return;
    final generation = _generation;
    saving = true;
    saveMessage = null;
    _notify();
    try {
      await saver.save(current);
      if (!_disposed && generation == _generation) {
        saveMessage = 'Đã lưu vé PNG vào thư viện ảnh';
      }
    } on PaymentFailure catch (e) {
      if (!_disposed && generation == _generation) saveMessage = e.message;
    } finally {
      if (!_disposed && generation == _generation) {
        saving = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _retry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// Entry ticket (mock-up ".ticket"): title row, dashed rule, QR 171dp on a
/// white tile, booking code and a hint. Raises the screen brightness while
/// it is on screen so the QR scans well.
class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.loader,
    this.courtName,
    this.brightness,
  });
  final TicketLoader loader;

  /// Shown on the right of the title row while the ticket loads.
  final String? courtName;
  final TicketBrightness? brightness;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: loader,
    builder: (context, _) {
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      final ticket = loader.ticket;
      final muted = theme.textTheme.bodySmall?.copyWith(
        color: colors.onSurfaceVariant,
        fontSize: 10,
      );
      final Widget qr;
      if (ticket != null) {
        qr = Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Image.memory(
            ticket.png,
            width: 155,
            height: 155,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
            semanticLabel: 'Mã QR check-in tại sân',
            errorBuilder: (_, _, _) => const SizedBox(
              width: 155,
              height: 155,
              child: Center(
                child: Text(
                  'Chưa hiển thị được QR. Hãy tải lại vé.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Color(0xFF3D4A63)),
                ),
              ),
            ),
          ),
        );
      } else if (loader.loading) {
        qr = const SizedBox(
          width: 171,
          height: 171,
          child: Center(child: CircularProgressIndicator()),
        );
      } else {
        qr = SizedBox(
          width: 171,
          height: 171,
          child: Center(
            child: Text(
              loader.error ?? 'Chưa tải được vé',
              textAlign: TextAlign.center,
              style: muted,
            ),
          ),
        );
      }
      final card = Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Vé vào sân',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  ticket?.courtName ?? courtName ?? '',
                  style: muted?.copyWith(fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 1,
              width: double.infinity,
              child: CustomPaint(painter: _DashedLine(colors.outlineVariant)),
            ),
            const SizedBox(height: 12),
            qr,
            const SizedBox(height: 8),
            if (ticket != null) ...[
              Text(
                ticket.bookingCode,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: .4,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Đưa mã này cho nhân viên khi đến sân',
                textAlign: TextAlign.center,
                style: muted,
              ),
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await Clipboard.setData(
                      ClipboardData(text: ticket.checkInCode),
                    );
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Đã sao chép mã vé')),
                    );
                  } on PlatformException {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Chưa sao chép được mã vé. Vui lòng thử lại.',
                        ),
                      ),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'Mã check-in: ${ticket.checkInCode}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: muted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.copy, size: 12, color: colors.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ] else if (!loader.loading)
              TextButton.icon(
                onPressed: loader.load,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Tải lại vé'),
              ),
          ],
        ),
      );
      return TicketBrightnessScope(
        controller: brightness ?? DeviceTicketBrightness.instance,
        child: card,
      );
    },
  );
}

class _DashedLine extends CustomPainter {
  const _DashedLine(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, 0), Offset(x + 3, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedLine old) => old.color != color;
}
