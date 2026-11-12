import 'package:flutter/material.dart';

import '../theme/sport_images.dart';
import '../theme/tokens.dart';
import 'sport_icon.dart';

/// Home header (mock-up "hero"): 294dp illustration with 28dp lower corners,
/// greeting (12/600 over 24/700) top-left, optional [trailing] top-right and a
/// floating white search pill (48dp) 17dp above the bottom edge. A soft scrim
/// keeps the text readable on any photo, in light and dark.
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
    required this.greeting,
    required this.title,
    this.sport,
    this.sportKind,
    this.imageAsset,
    this.trailing,
    this.searchHint = 'Tìm sân, môn thể thao, khu vực',
    this.searchController,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.onSearchTap,
    this.onFilterTap,
    this.height = 294,
  });
  final String greeting;
  final String title;

  /// Picks the illustration by sport; ignored when [imageAsset] is given.
  final String? sport;
  final SportKind? sportKind;
  final String? imageAsset;

  /// Top-right widget, e.g. an avatar or a notification button.
  final Widget? trailing;
  final String searchHint;

  /// With a controller the search pill is a live text field; with only
  /// [onSearchTap] it is a button that opens the search screen.
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback? onSearchTap;
  final VoidCallback? onFilterTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    // The illustration is bright in both themes (as in the mock-up), so the
    // text stays dark navy and the scrim is white.
    const ink = Color(0xFF182D51);
    const scrim = Colors.white;
    final asset =
        imageAsset ??
        (sportKind != null
            ? SportImages.hero(sportKind!)
            : SportImages.heroFor(sport));
    return SizedBox(
      height: height + top,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(Radii.sheet),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              asset,
              fit: BoxFit.cover,
              alignment: const Alignment(.24, 0),
              excludeFromSemantics: true,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, .45, 1],
                  colors: [
                    scrim.withValues(alpha: .55),
                    scrim.withValues(alpha: 0),
                    scrim.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: trailing == null ? 20 : 72,
              top: top + 13,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .6),
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        greeting,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 24,
                      height: 1.25,
                      letterSpacing: -.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              Positioned(right: 20, top: top + 13, child: trailing!),
            Positioned(
              left: 20,
              right: 20,
              bottom: 17,
              child: _SearchPill(
                hint: searchHint,
                controller: searchController,
                onChanged: onSearchChanged,
                onSubmitted: onSearchSubmitted,
                onTap: onSearchTap,
                onFilter: onFilterTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchPill extends StatelessWidget {
  const _SearchPill({
    required this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onFilter,
  });
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final VoidCallback? onFilter;

  @override
  Widget build(BuildContext context) {
    const muted = Color(0xFF5F6C84);
    const accent = Color(0xFF4F3FE8);
    final live = controller != null || onChanged != null;
    final Widget field = live
        ? TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textInputAction: TextInputAction.search,
            style: const TextStyle(
              color: Color(0xFF172238),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: hint,
              hintStyle: const TextStyle(color: muted, fontSize: 12),
            ),
          )
        : Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: muted, fontSize: 12),
          );
    return Material(
      color: Colors.white,
      elevation: 0,
      shadowColor: const Color(0x1F24314B),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: live ? null : onTap,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: Row(
              children: [
                const Icon(Icons.search, size: 18, color: muted),
                const SizedBox(width: 10),
                Expanded(child: field),
                if (onFilter != null)
                  IconButton(
                    tooltip: 'Bộ lọc',
                    onPressed: onFilter,
                    icon: const Icon(Icons.tune, size: 20, color: accent),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
