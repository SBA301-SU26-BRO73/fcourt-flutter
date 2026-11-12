import '../widgets/sport_icon.dart';

/// Bundled AI photos per sport (assets/images). A sport without its own photo
/// uses the nearest one: basketball falls back to football, volleyball and
/// everything else to tennis.
abstract final class SportImages {
  static const _dir = 'assets/images';

  /// Photo of an empty state (no results, nothing booked yet).
  static const emptyState = '$_dir/empty-state.webp';

  /// Illustration of the onboarding and sign-in screens.
  static const onboarding = '$_dir/onboarding-login.webp';

  static String _name(SportKind kind) => switch (kind) {
    SportKind.badminton => 'badminton',
    SportKind.pickleball => 'pickleball',
    SportKind.tennis => 'tennis',
    SportKind.football || SportKind.basketball => 'football',
    SportKind.volleyball || SportKind.other => 'tennis',
  };

  /// Court photo shown when a branch or a court has no photo of its own.
  static String placeholder(SportKind kind) =>
      '$_dir/court-placeholder-${_name(kind)}.webp';

  /// Wide illustration behind the home header.
  static String hero(SportKind kind) => '$_dir/hero-${_name(kind)}.webp';

  /// Same as [placeholder] for a sport (type) name such as "Cầu lông".
  static String placeholderFor(String? sportName) =>
      placeholder(sportKindOf(sportName));

  /// Same as [hero] for a sport (type) name.
  static String heroFor(String? sportName) => hero(sportKindOf(sportName));
}
