import 'package:flutter/material.dart';

import '../../../../app/widgets/wp3b_widgets.dart';
import 'countdown_timer_widget.dart';

/// Hold timer pinned under the status bar (mock-up ".hold"): 39dp high, soft
/// accent fill, clock + "Giữ chỗ còn" + countdown.
class HoldBanner extends StatelessWidget {
  const HoldBanner({
    super.key,
    required this.expiresAt,
    required this.onExpired,
  });
  final DateTime expiresAt;
  final VoidCallback onExpired;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('hold-banner'),
      color: colors.primaryContainer,
      child: SizedBox(
        height: 39,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 17, color: colors.onPrimaryContainer),
            const SizedBox(width: 8),
            Text(
              'Giữ chỗ còn',
              style: TextStyle(fontSize: 12, color: colors.onPrimaryContainer),
            ),
            const SizedBox(width: 8),
            CountdownTimerWidget(expiresAt: expiresAt, onExpired: onExpired),
          ],
        ),
      ),
    );
  }
}

/// Bordered 22dp-corner panel (mock-up ".panel" / ".bank").
class PayPanel extends StatelessWidget {
  const PayPanel({super.key, required this.child, this.padding = 15});
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: child,
    );
  }
}

/// The booking in one panel: photo, name, date and court, then code and
/// total (mock-up payment screen, first block).
class PayBookingSummary extends StatelessWidget {
  const PayBookingSummary({
    super.key,
    required this.name,
    required this.dateLine,
    required this.courtLine,
    required this.code,
    required this.amountText,
    required this.kind,
    this.totalLabel = 'Tổng thanh toán',
  });
  final String name, dateLine, courtLine, code, amountText, totalLabel;
  final SportKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
      fontSize: 11,
    );
    return PayPanel(
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 76,
                  height: 60,
                  child: SportPhoto(kind: kind),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(dateLine, style: muted),
                    const SizedBox(height: 6),
                    Text(courtLine, style: muted),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 25, thickness: 1, color: colors.outlineVariant),
          Row(
            children: [
              Expanded(
                child: Text(
                  '#$code · $totalLabel',
                  style: muted?.copyWith(fontSize: 10),
                ),
              ),
              Text(
                amountText,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Floating bar with one wide action (mock-up ".bottom-price > .wide").
class PayActionBar extends StatelessWidget {
  const PayActionBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward,
    this.buttonKey,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Key? buttonKey;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: colors.outlineVariant),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1015233D),
                blurRadius: 24,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: buttonKey,
              onPressed: loading ? null : onPressed,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                textStyle: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              child: loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (icon != null) ...[
                          const SizedBox(width: 8),
                          Icon(icon, size: 16),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
