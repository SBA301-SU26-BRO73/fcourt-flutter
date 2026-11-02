import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/error/failure.dart';
import '../../../core/storage/token_storage.dart';
import '../../operations/domain/counter.dart';
import '../domain/offline_ticket.dart';
import 'offline_remote.dart';
import 'offline_store.dart';

abstract class OfflineIdentity {
  Future<OfflineScope?> read();
  Future<void> save(OfflineScope scope);
}

class SecureOfflineIdentity implements OfflineIdentity {
  SecureOfflineIdentity(this.tokens, {FlutterSecureStorage? storage})
    : storage = storage ?? const FlutterSecureStorage();
  final TokenStorage tokens;
  final FlutterSecureStorage storage;
  @override
  Future<OfflineScope?> read() async {
    final session = await tokens.read();
    if (session == null) return null;
    try {
      // Only identifies the local cache owner. Server signature/activity is checked on sync.
      final claims = jsonDecode(
        utf8.decode(
          base64Url.decode(
            base64Url.normalize(session.accessToken.split('.')[1]),
          ),
        ),
      ) as Map;
      final raw = await storage.read(key: 'staff_offline_scope');
      if (raw == null) return null;
      final scope = jsonDecode(raw) as Map;
      if (claims['sub'].toString() != scope['userId'].toString()) return null;
      return OfflineScope(
        scope['userId'] as int,
        scope['branchId'] as int,
        scope['date'] as String,
      );
    } on FormatException {
      return null;
    } on RangeError {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> save(OfflineScope scope) => storage.write(
    key: 'staff_offline_scope',
    value: jsonEncode({
      'userId': scope.userId,
      'branchId': scope.branchId,
      'date': scope.date,
    }),
  );
}

class OfflineCoordinator extends ChangeNotifier {
  OfflineCoordinator({
    required this.store,
    required this.remote,
    required this.identity,
    DateTime Function()? clock,
    this.onQueued,
  }) : clock = clock ?? DateTime.now;
  final Future<OfflineStore> Function() store;
  final OfflineRemote remote;
  final OfflineIdentity identity;
  final DateTime Function() clock;
  final Future<void> Function()? onQueued;
  String message = 'Đồng bộ đầu ca để chuẩn bị vé ngoại tuyến.';
  int pendingCount = 0, conflictCount = 0;
  List<Map<String, Object?>> issues = const [];
  bool authRequired = false;
  bool busy = false;
  bool _syncing = false, _disposed = false;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<OfflineScope> scope() async {
    final value = await identity.read();
    if (value == null || value.date != businessToday(clock())) {
      throw const UnauthorizedFailure(
        'Cần phiên nhân viên và dữ liệu đầu ca hôm nay',
      );
    }
    return value;
  }

  Future<void> shiftSync() async {
    if (busy) return;
    busy = true;
    _changed();
    try {
      final snapshot = await remote.snapshot();
      if (snapshot.scope.date != businessToday(clock()) ||
          snapshot.scope.userId <= 0 ||
          snapshot.scope.branchId <= 0 ||
          snapshot.generatedAt.isAfter(
            clock().toUtc().add(const Duration(minutes: 1)),
          )) {
        throw const UnknownFailure('Dữ liệu đầu ca sai ngày hoặc chi nhánh');
      }
      final db = await store();
      await db.replace(snapshot);
      await identity.save(snapshot.scope);
      await db.purge(clock().toUtc());
      message =
          'Đã lưu ${snapshot.tickets.length} vé đầu ca. Nhận sân offline chờ đối soát máy chủ.';
      await flush();
    } on Failure catch (e) {
      message = e.message;
    } catch (_) {
      message =
          'Không đồng bộ được dữ liệu đầu ca. Giữ nguyên các lượt đang chờ.';
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<OfflineTicket> preview(String code) async {
    try {
      return await (await store()).preview(
        await scope(),
        code,
        clock().toUtc(),
      );
    } on Failure {
      rethrow;
    } catch (_) {
      throw const UnknownFailure('Không đọc được dữ liệu vé trên máy');
    }
  }

  Future<int> admit(String code, String key) async {
    final context = await scope();
    final db = await store();
    final result = await db.consume(context, code, key, clock().toUtc());
    pendingCount = await db.countPending(context);
    message = 'Đã nhận sân OFFLINE, đang chờ đối soát.';
    _changed();
    try {
      await onQueued?.call();
    } catch (_) {
      /* Durable queue survives scheduler failure. */
    }
    return result;
  }

  Future<void> flush() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final context = await identity.read();
      if (context == null) return;
      final db = await store();
      pendingCount = await db.countPending(context);
      if (await remote.activeUser() != context.userId) {
        throw const UnauthorizedFailure();
      }
      authRequired = false;
      for (var batch = 0; batch < 10; batch++) {
        final commands = await db.pending(context);
        if (commands.isEmpty) break;
        for (var offset = 0; offset < commands.length; offset += 4) {
          await Future.wait(
            commands.skip(offset).take(4).map((command) async {
              try {
                await remote.replay(command);
                await db.finish(command['command_key'] as String);
              } on Failure catch (e) {
                if (e is ServerFailure &&
                    [400, 404, 409, 422].contains(e.statusCode)) {
                  await db.finish(
                    command['command_key'] as String,
                    conflict: true,
                  );
                } else {
                  rethrow;
                }
              }
            }),
          );
        }
        if (commands.length < 50) break;
      }
      pendingCount = await db.countPending(context);
      conflictCount = await db.conflicts(context);
      issues = await db.issues(context);
      message = conflictCount > 0
          ? 'Có $conflictCount lượt cần đối soát; không tự ghi đè trạng thái vé.'
          : pendingCount == 0
          ? 'Đã đồng bộ các lượt nhận sân.'
          : 'Còn lượt đang chờ đồng bộ.';
    } on Failure catch (e) {
      authRequired =
          e is UnauthorizedFailure ||
          (e is ServerFailure && [401, 403].contains(e.statusCode));
      message = 'Chưa đồng bộ: ${e.message}';
    } catch (_) {
      message = 'Chưa đồng bộ được. Hàng đợi vẫn được giữ trên máy.';
    } finally {
      _syncing = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
