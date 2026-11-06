import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../domain/slot_invalidations.dart';

class StompSlotInvalidations implements SlotInvalidations {
  StompSlotInvalidations(String url, this.courtId) {
    final uri = Uri.parse(url);
    if (!{'ws', 'wss'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        courtId <= 0) {
      throw ArgumentError('Invalid public slot WebSocket URL');
    }
    _events = StreamController<String?>(onListen: () => _client.activate());
    _client = StompClient(
      config: StompConfig(
        url: url,
        reconnectDelay: const Duration(seconds: 3),
        connectionTimeout: const Duration(seconds: 5),
        heartbeatIncoming: Duration.zero,
        heartbeatOutgoing: const Duration(seconds: 10),
        onConnect: (_) {
          if (_closed) return;
          _client.subscribe(
            destination: '/topic/court-slots/$courtId',
            callback: (frame) {
              final date = parseDate(frame.body, courtId);
              if (!_closed && date != null) _events.add(date);
            },
          );
          _events.add(null);
        },
        onWebSocketError: (_) {},
        onStompError: (_) {},
      ),
    );
  }
  final int courtId;
  late final StompClient _client;
  late final StreamController<String?> _events;
  bool _closed = false;
  @override
  Stream<String?> get changes => _events.stream;

  static String? parseDate(String? payload, int courtId) {
    if (payload == null || payload.length > 1024) return null;
    try {
      final event = jsonDecode(payload) as Map<String, dynamic>;
      if (event['courtId'] != courtId) return null;
      final date = event['date'] as String;
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) return null;
      final parsed = DateTime.tryParse(date);
      if (parsed == null || parsed.toIso8601String().substring(0, 10) != date)
        return null;
      return date;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _client.deactivate();
    await _events.close();
  }
}
