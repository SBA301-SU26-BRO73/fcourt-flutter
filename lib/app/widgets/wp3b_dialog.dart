import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Look of an action in [Wp3bDialog] / [Wp3bSheet]: [primary] is the solid
/// indigo (lime in dark) pill, [tonal] the soft pill, [danger] the red pill,
/// [text] a plain label.
enum Wp3bActionKind { primary, tonal, danger, text }

class Wp3bAction extends StatelessWidget {
  const Wp3bAction(
    this.label, {
    super.key,
    required this.onPressed,
    this.kind = Wp3bActionKind.primary,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final Wp3bActionKind kind;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final child = busy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label, textAlign: TextAlign.center);
    const size = Size.fromHeight(52);
    return switch (kind) {
      Wp3bActionKind.primary => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(minimumSize: size),
        child: child,
      ),
      Wp3bActionKind.danger => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: size,
          backgroundColor: colors.error,
          foregroundColor: colors.onError,
        ),
        child: child,
      ),
      Wp3bActionKind.tonal => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: size,
          backgroundColor: colors.surfaceContainerLow,
          foregroundColor: colors.onSurface,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: child,
      ),
      Wp3bActionKind.text => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(Gap.touch),
          foregroundColor: colors.onSurfaceVariant,
        ),
        child: child,
      ),
    };
  }
}

/// Round icon on a soft tint above a sheet or dialog title.
class Wp3bBadge extends StatelessWidget {
  const Wp3bBadge(this.icon, {super.key, this.tone});
  final IconData icon;
  final StatusTone? tone;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tone?.container ?? colors.primaryContainer,
      ),
      child: Icon(
        icon,
        size: 28,
        color: tone?.color ?? colors.onPrimaryContainer,
      ),
    );
  }
}

List<Widget> _stack(List<Widget> actions) => [
  for (var i = 0; i < actions.length; i++) ...[
    if (i > 0) const SizedBox(height: Gap.sm),
    actions[i],
  ],
];

/// Confirmation dialog of the WP3b look: 28dp corners, round icon badge,
/// centred title, optional [message] / [content], full-width pill actions
/// (first = main). Still an [AlertDialog], so it behaves like one.
class Wp3bDialog extends StatelessWidget {
  const Wp3bDialog({
    super.key,
    required this.title,
    required this.actions,
    this.icon,
    this.tone,
    this.message,
    this.content,
  });
  final String title;
  final IconData? icon;
  final StatusTone? tone;
  final String? message;
  final Widget? content;

  /// Main action first, then the secondary ones.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: colors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sheet),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowDirection: VerticalDirection.down,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Gap.lg),
                  child: Wp3bBadge(icon!, tone: tone),
                ),
              ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: Gap.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            if (content != null) ...[const SizedBox(height: Gap.lg), content!],
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _stack(actions),
          ),
        ),
      ],
    );
  }
}

/// Body of a modal bottom sheet in the WP3b look: drag handle, title with
/// optional subtitle, scrolling [child] and pill [actions]. The sheet shape
/// (28dp top corners) and surface come from the theme.
class Wp3bSheet extends StatelessWidget {
  const Wp3bSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.actions = const [],
  });
  final String title;
  final String? subtitle;

  /// Optional control at the end of the title row (e.g. a close button).
  final Widget? trailing;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 14),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: text.titleLarge?.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                          ),
                          if (subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                subtitle!,
                                style: text.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: child,
                ),
              ),
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _stack(actions),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A "label / value" line of a receipt (court, time, amount).
class Wp3bInfoRow extends StatelessWidget {
  const Wp3bInfoRow(this.label, this.value, {super.key, this.strong = false});
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: strong ? colors.primary : colors.onSurface,
                fontSize: strong ? 16 : 13,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft rounded block that groups [Wp3bInfoRow]s.
class Wp3bInfoBlock extends StatelessWidget {
  const Wp3bInfoBlock({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(Radii.md),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

/// Field with its 12/700 label above it (login-form rhythm). The field itself
/// should use `hintText`, not `labelText`.
class Wp3bField extends StatelessWidget {
  const Wp3bField(this.label, {super.key, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      child,
    ],
  );
}
