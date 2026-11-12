import 'package:flutter/material.dart';

import '../../../app/widgets/fc_widgets.dart';

/// Mock-up `.appointment`: 17dp vertical padding, a hairline on top, a 54dp
/// time column (17px start, 10px end) and the booking details on the right:
/// name and reference, a muted line, then a state tag with an optional action.
class AppointmentRow extends StatelessWidget {
  const AppointmentRow({
    super.key,
    required this.start,
    required this.end,
    required this.title,
    required this.line,
    required this.tag,
    required this.tone,
    this.reference,
    this.action,
  });
  final String start;
  final String end;
  final String title;

  /// Muted line under the title (court, phone).
  final String line;
  final String tag;
  final StatusTone tone;

  /// Small id at the top right, e.g. `#12`.
  final String? reference;

  /// Button or icon on the right of the tag row.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 10, color: colors.onSurfaceVariant);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 54,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    start,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(end, style: muted),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (reference != null) ...[
                        const SizedBox(width: 8),
                        Text(reference!, style: muted.copyWith(fontSize: 9)),
                      ],
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 7, bottom: 10),
                    child: Text(line, style: muted),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _StateTag(tag, tone: tone),
                        ),
                      ),
                      if (action != null) ...[
                        const SizedBox(width: 8),
                        action!,
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mock-up `.tag` in a list row: 9px bold, padding 6x8, 15dp radius.
class _StateTag extends StatelessWidget {
  const _StateTag(this.label, {required this.tone});
  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: tone.container,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: tone.color,
        ),
      ),
    ),
  );
}

/// Small filled action of an appointment row (mock-up `.appointment .primary`).
class AppointmentAction extends StatelessWidget {
  const AppointmentAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      textStyle: TextStyle(
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
    child: busy
        ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13),
              const SizedBox(width: 5),
              Text(label),
            ],
          ),
  );
}
