import 'dart:io';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/offline/domain/offline_ticket.dart';
import 'package:fcourt/features/offline/data/offline_store.dart';
import 'package:fcourt/features/offline/data/offline_remote.dart';
import 'package:fcourt/features/offline/data/offline_coordinator.dart';
import 'package:fcourt/features/offline/data/offline_operations.dart';
import 'package:fcourt/features/offline/data/offline_access.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fcourt/core/storage/token_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../operations/operations_test.dart' show FakeOperations;
import '../../helpers/fake_adapter.dart';

const scope = OfflineScope(100, 7, '2026-11-01');
final now = DateTime.utc(2026, 11, 1, 2);
OfflineSnapshot makeSnapshot() =>
    OfflineSnapshot(scope, now.subtract(const Duration(minutes: 5)), [
      OfflineTicket(
        bookingId: 42,
        hash: ticketHash('ticket'),
        court: 'Sân 1',
        name: 'Khoa',
        from: now.subtract(const Duration(minutes: 15)),
        until: now.add(const Duration(hours: 1)),
        permit: 'signed-fixture',
      ),
    ]);

class Identity implements OfflineIdentity {
  OfflineScope? value = scope;
  @override
  Future<OfflineScope?> read() async => value;
  @override
  Future<void> save(OfflineScope scope) async => value = scope;
}

class Remote implements OfflineRemote {
  Failure? error;
  final keys = <String>[];
  @override
  Future<int> activeUser() async => 100;
  @override
  Future<OfflineSnapshot> snapshot() async => makeSnapshot();
  @override
  Future<void> replay(Map<String, Object?> command) async {
    keys.add(command['command_key'] as String);
    if (error != null) throw error!;
  }
}

void main() {
  test(
    'offline http snapshot and replay preserve identity timestamp and uuid',
    () async {
      final adapter = FakeAdapter(
        (r) => jsonResponse(
          200,
          r.path.endsWith('/me')
              ? {'userId': 100, 'active': true}
              : r.method == 'GET'
              ? {
                  'userId': 100,
                  'branchId': 7,
                  'date': '2026-11-01',
                  'generatedAt': now.toIso8601String(),
                  'tickets': [
                    {
                      'bookingId': 42,
                      'codeHash': ticketHash('ticket'),
                      'courtName': 'Sân 1',
                      'customerName': 'Khoa',
                      'validFrom': now
                          .subtract(const Duration(minutes: 15))
                          .toIso8601String(),
                      'validUntil': now
                          .add(const Duration(hours: 1))
                          .toIso8601String(),
                      'permit': 'signed-fixture',
                    },
                  ],
                }
              : {
                  'bookingId': 42,
                  'branchId': 7,
                  'status': 'CHECKED_IN',
                  'checkedInAt': now.toIso8601String(),
                },
        ),
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = adapter;
      final remote = HttpOfflineRemote(dio);
      expect(await remote.activeUser(), 100);
      expect(
        (await remote.snapshot()).tickets.single.hash,
        ticketHash('ticket'),
      );
      await remote.replay({
        'command_key': 'same',
        'booking_id': 42,
        'branch_id': 7,
        'permit': 'signed-fixture',
        'occurred_at': now.toIso8601String(),
      });
      expect(adapter.requests.last.data, {
        'permit': 'signed-fixture',
        'occurredAt': now.toIso8601String(),
      });
      expect(adapter.requests.last.headers['Idempotency-Key'], 'same');
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late OfflineStore store;
  late Directory dir;
  late String path;
  test('secure identity follows active subject and logout', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final payload = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'sub': '100',
              'roles': ['STAFF'],
              'exp':
                  now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
                  1000,
            }),
          ),
        )
        .replaceAll('=', '');
    final tokens = InMemoryTokenStorage(
      AuthTokens(
        accessToken: 'header.$payload.signature',
        refreshToken: 'fixture-refresh',
      ),
    );
    final identity = SecureOfflineIdentity(tokens, clock: () => now);
    await identity.save(scope);
    expect((await identity.read())!.userId, 100);
    await tokens.clear();
    expect(await identity.read(), isNull);
    await tokens.save(
      const AuthTokens(accessToken: 'invalid', refreshToken: 'fixture-refresh'),
    );
    expect(await identity.read(), isNull);
  });
  test(
    'shift sync refreshes snapshot and drains a durable pending admission',
    () async {
      final remote = Remote();
      final identity = Identity();
      final coordinator = OfflineCoordinator(
        store: () async => store,
        remote: remote,
        identity: identity,
        clock: () => now,
      );
      await coordinator.shiftSync();
      expect(coordinator.busy, isFalse);
      expect((await coordinator.preview('ticket')).bookingId, 42);
      await coordinator.admit('ticket', 'same');
      await coordinator.shiftSync();
      expect(remote.keys, ['same']);
      expect(coordinator.pendingCount, 0);
      coordinator.dispose();
    },
  );
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fcourt-offline-');
    path = '${dir.path}/test.db';
    store = await OfflineStore.open(factory: databaseFactoryFfi, path: path);
    await store.replace(makeSnapshot());
  });
  tearDown(() async {
    if (store.db.isOpen) await store.close();
    for (final name in ['test.db', 'test.db-wal', 'test.db-shm']) {
      final file = File('${dir.path}/$name');
      if (await file.exists()) await file.delete();
    }
    await dir.delete();
  });
  test(
    'sqlite admission survives restart and prevents duplicate with new key',
    () async {
      expect(await store.consume(scope, 'ticket', 'same', now), 42);
      await store.close();
      store = await OfflineStore.open(factory: databaseFactoryFfi, path: path);
      expect(await store.consume(scope, 'ticket', 'same', now), 42);
      await expectLater(
        store.consume(scope, 'ticket', 'new', now),
        throwsA(isA<ServerFailure>()),
      );
      expect((await store.pending(scope)).single['command_key'], 'same');
      final rows = await store.db.query('tickets');
      expect(rows.single['code_hash'], isNot('ticket'));
    },
  );
  test('concurrent local scans admit exactly once', () async {
    Future<bool> attempt(String key) async {
      try {
        await store.consume(scope, 'ticket', key, now);
        return true;
      } on Failure {
        return false;
      }
    }

    final results = await Future.wait([attempt('one'), attempt('two')]);
    expect(results.where((v) => v), hasLength(1));
    expect(await store.pending(scope), hasLength(1));
  });
  test('new snapshot preserves consumed state and pending command', () async {
    await store.consume(scope, 'ticket', 'same', now);
    await store.replace(makeSnapshot());
    await expectLater(
      store.preview(scope, 'ticket', now),
      throwsA(isA<ServerFailure>()),
    );
    expect(await store.pending(scope), hasLength(1));
  });
  test('scope window and stale snapshot all fail closed', () async {
    await expectLater(
      store.preview(const OfflineScope(101, 7, '2026-11-01'), 'ticket', now),
      throwsA(isA<ServerFailure>()),
    );
    await expectLater(
      store.preview(const OfflineScope(100, 8, '2026-11-01'), 'ticket', now),
      throwsA(isA<ServerFailure>()),
    );
    await expectLater(
      store.preview(scope, 'ticket', now.add(const Duration(hours: 2))),
      throwsA(isA<ServerFailure>()),
    );
    await store.replace(
      OfflineSnapshot(
        scope,
        now.subtract(const Duration(hours: 13)),
        makeSnapshot().tickets,
      ),
    );
    await expectLater(
      store.preview(scope, 'ticket', now),
      throwsA(isA<ServerFailure>()),
    );
  });
  test(
    'network replay retains exact key and terminal conflict remains visible',
    () async {
      final remote = Remote()..error = const NetworkFailure();
      final identity = Identity();
      final coordinator = OfflineCoordinator(
        store: () async => store,
        remote: remote,
        identity: identity,
        clock: () => now,
      );
      await coordinator.admit('ticket', 'same');
      await coordinator.flush();
      expect(await store.pending(scope), hasLength(1));
      remote.error = const ServerFailure('already used', statusCode: 409);
      await coordinator.flush();
      expect(remote.keys, ['same', 'same']);
      expect(await store.pending(scope), isEmpty);
      expect(await store.conflicts(scope), 1);
      expect((await store.issues(scope)).single['booking_id'], 42);
      expect((await store.db.query('outbox')).single['permit'], isNull);
      coordinator.dispose();
    },
  );
  test('logout prevents admission and sync of previous user cache', () async {
    final identity = Identity()..value = null;
    final remote = Remote();
    final coordinator = OfflineCoordinator(
      store: () async => store,
      remote: remote,
      identity: identity,
      clock: () => now,
    );
    await expectLater(
      coordinator.admit('ticket', 'same'),
      throwsA(isA<UnauthorizedFailure>()),
    );
    await coordinator.flush();
    expect(remote.keys, isEmpty);
    coordinator.dispose();
  });
  test(
    'successful reconciliation removes permit and repeated flush cannot resend',
    () async {
      final remote = Remote();
      final coordinator = OfflineCoordinator(
        store: () async => store,
        remote: remote,
        identity: Identity(),
        clock: () => now,
      );
      await coordinator.admit('ticket', 'same');
      await coordinator.flush();
      await coordinator.flush();
      expect(remote.keys, ['same']);
      expect(await store.pending(scope), isEmpty);
      expect((await store.db.query('outbox')).single['permit'], isNull);
      coordinator.dispose();
    },
  );
  test('network-only preview fallback labels provisional admission', () async {
    final coordinator = OfflineCoordinator(
      store: () async => store,
      remote: Remote(),
      identity: Identity(),
      clock: () => now,
    );
    final online = FakeOperations()..error = const NetworkFailure();
    final operations = OfflineOperations(online, coordinator);
    expect((await operations.preview('ticket')).offline, isTrue);
    expect(await operations.checkIn('ticket', 'same'), 42);
    online.error = const UnauthorizedFailure();
    await expectLater(
      operations.preview('other'),
      throwsA(isA<UnauthorizedFailure>()),
    );
    coordinator.dispose();
  });

  test(
    'cold access requires current day and fresh persisted snapshot',
    () async {
      final identity = Identity();
      final coordinator = OfflineCoordinator(
        store: () async => store,
        remote: Remote(),
        identity: identity,
        clock: () => now,
      );
      expect((await OfflineAccess(coordinator).restore())!.id, 100);
      await store.close();
      store = await OfflineStore.open(factory: databaseFactoryFfi, path: path);
      expect((await OfflineAccess(coordinator).restore())!.id, 100);
      identity.value = const OfflineScope(100, 7, '2026-11-02');
      expect(await OfflineAccess(coordinator).restore(), isNull);
      identity.value = scope;
      await store.replace(
        OfflineSnapshot(
          scope,
          now.subtract(const Duration(hours: 13)),
          makeSnapshot().tickets,
        ),
      );
      expect(await OfflineAccess(coordinator).restore(), isNull);
      coordinator.dispose();
    },
  );

  test(
    'cached-only repository admits without contacting online APIs',
    () async {
      final remote = Remote();
      final coordinator = OfflineCoordinator(
        store: () async => store,
        remote: remote,
        identity: Identity(),
        clock: () => now,
      );
      final operations = OfflineOperations.cached(coordinator);
      expect((await operations.preview('ticket')).offline, isTrue);
      expect(await operations.checkIn('ticket', 'local-key'), 42);
      expect(remote.keys, isEmpty);
      expect(await store.countPending(scope), 1);
      await expectLater(
        operations.preview('ticket'),
        throwsA(isA<ServerFailure>()),
      );
      coordinator.dispose();
    },
  );

  test('secure offline scope rejects expired, premature and non-staff tokens', () async {
    final tokens = InMemoryTokenStorage();
    final identity = SecureOfflineIdentity(tokens, clock: () => now);
    await identity.save(scope);
    final epoch = now.millisecondsSinceEpoch ~/ 1000;
    Future<void> setClaims(Map<String, Object?> claims) => tokens.save(
      AuthTokens(
        accessToken:
            'header.${base64Url.encode(utf8.encode(jsonEncode(claims)))}.signature',
        refreshToken: 'fixture',
      ),
    );
    final valid = <String, Object?>{
      'sub': '100',
      'exp': epoch + 3600,
      'roles': ['STAFF'],
    };
    await setClaims(valid);
    expect((await identity.read())!.userId, 100);
    for (final change in [
      {'exp': epoch},
      {'nbf': epoch + 1},
      {'exp': 'invalid'},
      {
        'roles': ['ADMIN'],
      },
      {'roles': 'STAFF'},
      {'sub': '200'},
    ]) {
      await setClaims({...valid, ...change});
      expect(await identity.read(), isNull, reason: '$change');
    }
    await tokens.clear();
    expect(await identity.read(), isNull);
  });
}
