class PushPayload {
  const PushPayload({
    required this.type,
    required this.notificationId,
    required this.bookingId,
    required this.route,
    this.title,
    this.body,
    this.foreground = false,
  });

  final String? type;
  final String? notificationId;
  final String? bookingId;
  final String? route;

  /// Visible text of a message received while the app is open.
  final String? title;
  final String? body;

  /// True when the app was in the foreground: show it, navigate only on tap.
  final bool foreground;

  factory PushPayload.fromMap(
    Map<String, dynamic> data, {
    String? title,
    String? body,
    bool foreground = false,
  }) => PushPayload(
    type: data['type']?.toString(),
    notificationId: data['notificationId']?.toString(),
    bookingId: data['bookingId']?.toString(),
    route: data['route']?.toString(),
    title: title ?? data['title']?.toString(),
    body: body ?? data['body']?.toString(),
    foreground: foreground,
  );

  Map<String, dynamic> toMap() => {
    'type': type,
    'notificationId': notificationId,
    'bookingId': bookingId,
    'route': route,
  };
}
