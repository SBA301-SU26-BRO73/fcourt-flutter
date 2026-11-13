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
    _events = StreamController<SlotChange?>(onListen: () => _client.activate());
    _client = StompClient(
      config: StompConfig(
        url: url,
        reconnectDelay: const Duration(seconds: 3),
        connectionTimeout: const Duration(seconds: 5),
        heartbeatIncoming: Duration.zero,
        heartbeatOutgoing: const Duration(seconds: 10),
        onConnect: (_) {
          if (_closed) return;
          _connected = true;
          _client.subscribe(
            destination: '/topic/court-slots/$courtId',
            callback: (frame) {
              final change = parseChange(frame.body, courtId);
              if (!_closed && change != null) _events.add(change);
            },
          );
          _events.add(null);
        },
        onDisconnect: (_) => _connected = false,
        onWebSocketDone: () => _connected = false,
        onWebSocketError: (_) => _connected = false,
        onStompError: (_) {},
      ),
    );
  }
  final int courtId;
  late final StompClient _client;
  late final StreamController<SlotChange?> _events;
  bool _closed = false, _connected = false;
  @override
  Stream<SlotChange?> get changes => _events.stream;
  @override
  bool get connected => _connected && !_closed;

  static String? parseDate(String? payload, int courtId) =>
      parseChange(payload, courtId)?.date;

  static const _types = {
    'SLOT_CHANGED',
    'HOLD_CREATED',
    'HOLD_RELEASED',
    'HOLD_EXPIRED',
    'LOCK_CREATED',
    'LOCK_REMOVED',
  };
  static const _lockTypes = {'OUT_OF_SERVICE', 'PRIVATE_EVENT'};

  /// Unknown or missing `type` degrades to SLOT_CHANGED (older backends).
  static SlotChange? parseChange(String? payload, int courtId) {
    if (payload == null || payload.length > 1024) {
      return null;
    }
    try {
      final event = jsonDecode(payload) as Map<String, dynamic>;
      if (event['courtId'] != courtId) {
        return null;
      }
      final date = event['date'] as String;
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
        return null;
      }
      final parsed = DateTime.tryParse(date);
      if (parsed == null || parsed.toIso8601String().substring(0, 10) != date) {
        return null;
      }
      final type = event['type'];
      final lockType = event['lockType'];
      final safeType = type is String && _types.contains(type)
          ? type
          : 'SLOT_CHANGED';
      return SlotChange(
        date,
        type: safeType,
        lockType:
            safeType.startsWith('LOCK_') &&
                lockType is String &&
                _lockTypes.contains(lockType)
            ? lockType
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _connected = false;
    _client.deactivate();
    await _events.close();
  }
}
