class PushPayload {
  const PushPayload({
    required this.type,
    required this.notificationId,
    required this.bookingId,
    required this.route,
  });

  final String? type;
  final String? notificationId;
  final String? bookingId;
  final String? route;

  factory PushPayload.fromMap(Map<String, dynamic> data) => PushPayload(
    type: data['type']?.toString(),
    notificationId: data['notificationId']?.toString(),
    bookingId: data['bookingId']?.toString(),
    route: data['route']?.toString(),
  );

  Map<String, dynamic> toMap() => {
    'type': type,
    'notificationId': notificationId,
    'bookingId': bookingId,
    'route': route,
  };
}
