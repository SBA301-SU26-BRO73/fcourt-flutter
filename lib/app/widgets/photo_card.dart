import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/sport_images.dart';
import '../theme/tokens.dart';
import 'sport_icon.dart';

/// Photo that falls back to the bundled placeholder of the sport when the
/// URL is empty or fails to load. Always fills its parent.
class SportPhoto extends StatelessWidget {
  const SportPhoto({
    super.key,
    this.url,
    this.sport,
    this.kind,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });
  final String? url;

  /// Sport (type) name used to pick the placeholder, e.g. "Cầu lông".
  final String? sport;

  /// Sport kind, when already known; wins over [sport].
  final SportKind? kind;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final asset = kind != null
        ? SportImages.placeholder(kind!)
        : SportImages.placeholderFor(sport);
    final fallback = Image.asset(
      asset,
      fit: fit,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      excludeFromSemantics: true,
    );
    final u = url?.trim();
    if (u == null || u.isEmpty) return fallback;
    return Image.network(
      u,
      fit: fit,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => fallback,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : fallback,
    );
  }
}

/// Large photo card (mock-up "court"): 23dp corners, 1dp line, photo 163dp
/// tall with a white sport chip top-left and a lime rank badge bottom-right,
/// then name, address, and a row with price (accent) and rating (green).
class PhotoCard extends StatelessWidget {
  const PhotoCard({
    super.key,
    required this.title,
    this.imageUrl,
    this.sport,
    this.sportKind,
    this.sportLabel,
    this.badge,
    this.subtitle,
    this.priceText,
    this.ratingText,
    this.onTap,
    this.photoHeight = 163,
  });
  final String title;
  final String? imageUrl;

  /// Sport (type) name; picks the placeholder photo and the chip icon.
  final String? sport;
  final SportKind? sportKind;

  /// Text of the white chip over the photo (defaults to [sport]).
  final String? sportLabel;

  /// Short text in the lime circle (rank "#1", count...).
  final String? badge;
  final String? subtitle;

  /// Accent price line, e.g. "Từ 50.000đ/giờ".
  final String? priceText;

  /// Rating line, e.g. "4,6 (128)".
  final String? ratingText;
  final VoidCallback? onTap;
  final double photoHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final kind = sportKind ?? sportKindOf(sport);
    final chip = sportLabel ?? sport;
    final shape = BorderRadius.circular(23);
    return Material(
      color: colors.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: shape,
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: photoHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SportPhoto(url: imageUrl, kind: kind),
                  if (chip != null && chip.isNotEmpty)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _PhotoChip(kind: kind, label: chip),
                    ),
                  if (badge != null)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Container(
                        width: 33,
                        height: 33,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.lime,
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Color(0xFF21303B),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      letterSpacing: -.3,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (priceText != null || ratingText != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (priceText != null)
                          Expanded(
                            child: Text(
                              priceText!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        if (ratingText != null) ...[
                          const SizedBox(width: Gap.sm),
                          Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: context.fc.success.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ratingText!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: context.fc.success.color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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
