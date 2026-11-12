import 'package:flutter/material.dart';

import '../theme/sport_images.dart';
import '../theme/tokens.dart';

/// Empty state with the shared racket-and-shuttle picture in a round white
/// plate (the picture has a white background, so the plate reads in both
/// themes). Title, message and an optional action sit below it.
class PhotoEmptyState extends StatelessWidget {
  const PhotoEmptyState({
    super.key,
    required this.message,
    this.title,
    this.action,
    this.size = 120,
  });
  final String message;
  final String? title;
  final Widget? action;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xl, horizontal: Gap.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: Image.asset(
              SportImages.emptyState,
              width: size,
              height: size,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(height: Gap.lg),
          if (title != null) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Gap.sm),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[const SizedBox(height: Gap.md), action!],
        ],
      ),
    );
  }
}
